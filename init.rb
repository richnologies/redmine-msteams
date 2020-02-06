require 'redmine'

require_dependency 'redmine_msteams/listener'

Redmine::Plugin.register :redmine_msteams do
	name 'Redmine MS Teams'
	author 'PSI Development Team'
	url 'https://github.com/richnologies/redmine-msteams'
	author_url 'https://www.psi-mobile.com/'
	description 'MSTeams chat integration'
	version '0.3'

	requires_redmine :version_or_higher => '0.8.0'

	settings \
		:default => {
			'callback_url' => 'https://outlook.office.com/webhook/',
			'channel' => nil,
			'icon' => 'https://raw.github.com/sciyoshi/redmine-slack/gh-pages/icon.png',
			'username' => 'redmine',
			'display_watchers' => 'no'
		},
		:partial => 'settings/msteams_settings'
end
