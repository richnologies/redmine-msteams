require 'msteams-ruby-client'

class MSTeamsListener < Redmine::Hook::Listener
	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless channel and url
		return if issue.is_private?

		msg = "[#{escape issue.project}] #{escape issue.author} created [#{escape issue}](#{object_url issue})#{mentions issue.description}"

		attachment = {}
		attachment[:text] = escape issue.description if issue.description
		attachment[:facts] = [{
			:name => I18n.t("field_status"),
			:value => escape(issue.status.to_s),
			:short => true
		}, {
			:name => I18n.t("field_priority"),
			:value => escape(issue.priority.to_s),
			:short => true
		}, {
			:name => I18n.t("field_assigned_to"),
			:value => escape(issue.assigned_to.to_s),
			:short => true
		}]

		attachment[:facts] << {
			:name => I18n.t("field_watcher"),
			:value => escape(issue.watcher_users.join(', ')),
			:short => true
		} if Setting.plugin_redmine_msteams[:display_watchers] == 'yes'

		speak msg, channel, attachment, url
	end

	def controller_issues_edit_after_save(context={})
		issue = context[:issue]
		journal = context[:journal]

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless channel and url and Setting.plugin_redmine_msteams[:post_updates] == '1'
		return if issue.is_private?

		msg = "[#{escape issue.project}] #{escape journal.user.to_s} updated [#{escape issue}](#{object_url issue})#{mentions journal.notes}"

		attachment = {}
		attachment[:text] = escape journal.notes if journal.notes
		attachment[:facts] = journal.details.map { |d| detail_to_field d }

		speak msg, channel, attachment, url
	end

	def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		issue = context[:issue]
		journal = issue.current_journal
		changeset = context[:changeset]

		channel = channel_for_project issue.project
		url = url_for_project issue.project

		return unless channel and url and issue.save
		return if issue.is_private?

		msg = "[#{escape issue.project}] #{escape journal.user.to_s} updated [#{escape issue}](#{object_url issue})"

		repository = changeset.repository

		if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
			host, port, prefix = $2, $4, $5
			revision_url = Rails.application.routes.url_for(
				:controller => 'repositories',
				:action => 'revision',
				:id => repository.project,
				:repository_id => repository.identifier_param,
				:rev => changeset.revision,
				:host => host,
				:protocol => Setting.protocol,
				:port => port,
				:script_name => prefix
			)
		else
			revision_url = Rails.application.routes.url_for(
				:controller => 'repositories',
				:action => 'revision',
				:id => repository.project,
				:repository_id => repository.identifier_param,
				:rev => changeset.revision,
				:host => Setting.host_name,
				:protocol => Setting.protocol
			)
		end

		attachment = {}
		attachment[:text] = ll(Setting.default_language, :text_status_changed_by_changeset, "[#{escape changeset.comments}](#{revision_url})")
		attachment[:facts] = journal.details.map { |d| detail_to_field d }

		speak msg, channel, attachment, url
	end

	def controller_wiki_edit_after_save(context = { })
		return unless Setting.plugin_redmine_msteams[:post_wiki_updates] == '1'

		project = context[:project]
		page = context[:page]

		user = page.content.author
		project_url = "[#{escape project}](#{object_url project})"
		page_url = "[#{page.title}](#{object_url page})"
		comment = "[#{project_url}] #{page_url} updated by *#{user}*"

		channel = channel_for_project project
		url = url_for_project project

		attachment = nil
		if not page.content.comments.empty?
			attachment = {}
			attachment[:text] = "#{escape page.content.comments}"
		end

		speak comment, channel, attachment, url
	end

	def speak(msg, channel, attachment=nil, url=nil)
		url = Setting.plugin_redmine_msteams[:msteams_url] if not url
		username = Setting.plugin_redmine_msteams[:username]
		icon = Setting.plugin_redmine_msteams[:icon]

		params = {
			:@context => "http://schema.org/extensions",
  		:@type => "MessageCard",
			:text => msg
		}

		params[:sections] = [attachment] if attachment

		begin
			uri = URI.parse(url)
			request = Net::HTTP::Post.new(uri.request_uri)
			request['Content-Type'] = 'application/json'
			request.body = params.to_json

			http = Net::HTTP.new(uri.host, uri.port)
			http.use_ssl = true
			http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			http.start { |h| h.request(request) }
		rescue Exception => e
			logger.warn("cannot connect to #{url}")
			logger.warn(e)
		end
	end

private
	def escape(msg)
		msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
	end

	def object_url(obj)
		if Setting.host_name.to_s =~ /\A(https?\:\/\/)?(.+?)(\:(\d+))?(\/.+)?\z/i
			host, port, prefix = $2, $4, $5
			Rails.application.routes.url_for(obj.event_url({
				:host => host,
				:protocol => Setting.protocol,
				:port => port,
				:script_name => prefix
			}))
		else
			Rails.application.routes.url_for(obj.event_url({
				:host => Setting.host_name,
				:protocol => Setting.protocol
			}))
		end
	end

	def url_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("MSTeams URL")

		return [
			(proj.custom_value_for(cf).value rescue nil),
			(url_for_project proj.parent),
			Setting.plugin_redmine_msteams[:msteams_url],
		].find{|v| v.present?}
	end

	def channel_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("MSTeams Channel")

		val = [
			(proj.custom_value_for(cf).value rescue nil),
			(channel_for_project proj.parent),
			Setting.plugin_redmine_msteams[:channel],
		].find{|v| v.present?}

		# Channel name '-' is reserved for NOT notifying
		return nil if val.to_s == '-'
		val
	end

	def detail_to_field(detail)
		if detail.property == "cf"
			key = CustomField.find(detail.prop_key).name rescue nil
			title = key
		elsif detail.property == "attachment"
			key = "attachment"
			title = I18n.t :label_attachment
		else
			key = detail.prop_key.to_s.sub("_id", "")
			title = I18n.t "field_#{key}"
		end

		short = true
		value = escape detail.value.to_s

		case key
		when "title", "subject", "description"
			short = false
		when "tracker"
			tracker = Tracker.find(detail.value) rescue nil
			value = escape tracker.to_s
		when "project"
			project = Project.find(detail.value) rescue nil
			value = escape project.to_s
		when "status"
			status = IssueStatus.find(detail.value) rescue nil
			value = escape status.to_s
		when "priority"
			priority = IssuePriority.find(detail.value) rescue nil
			value = escape priority.to_s
		when "category"
			category = IssueCategory.find(detail.value) rescue nil
			value = escape category.to_s
		when "assigned_to"
			user = User.find(detail.value) rescue nil
			value = escape user.to_s
		when "fixed_version"
			version = Version.find(detail.value) rescue nil
			value = escape version.to_s
		when "attachment"
			attachment = Attachment.find(detail.prop_key) rescue nil
			value = "[#{escape attachment.filename}](#{object_url attachment})" if attachment
		when "parent"
			issue = Issue.find(detail.value) rescue nil
			value = "[#{escape issue}](#{object_url issue})" if issue
		end

		value = "-" if value.empty?

		result = { :name => title, :value => value }
		result[:short] = true if short
		result
	end

	def mentions text
		names = extract_usernames text
		names.present? ? "\nTo: " + names.join(', ') : nil
	end

	def extract_usernames text = ''
		# MSTeams usernames may only contain lowercase letters, numbers,
		# dashes and underscores and must start with a letter or number.
		text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
	end
end
