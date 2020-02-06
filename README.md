# MSTeams chat plugin for Redmine

This plugin posts updates to issues in your Redmine installation to a MSTeams
channel. Improvements are welcome! Just send a pull request.

## Install

From your Redmine plugins directory, clone this repository as `redmine_msteams` (note
the underscore!):

    cd $REDMINE_ROOT
    git clone https://github.com/richnologies/redmine-msteams --single-branch --branch msteams plugins/redmine_msteams
    bundle install
    bundle exec rake redmine:plugins:migrate RAILS_ENV=production

from the plugin directory.

Restart Redmine, and you should see the plugin show up in the Plugins page.
Under the configuration options, set the MSTeams API URL to the URL for an
Incoming WebHook integration in your MSTeams channel.

## UnInstall

Uninstall ``redmine-msteams``

    cd $REDMINE_ROOT
    bundle exec rake redmine:plugins:migrate NAME=redmine_msteams VERSION=0 RAILS_ENV=production
    rm -rf plugins/redmine_msteams

Restart Redmine (application server)

## Customized Routing

You can also route messages to different channels on a per-project basis. To
do this, create a project custom field (Administration > Custom fields > Project)
named `MSTeams Channel`. If no custom channel is defined for a project, the parent
project will be checked (or the default will be used). To prevent all notifications
from being sent for a project, set the custom channel to `-`.

For more information, see http://www.redmine.org/projects/redmine/wiki/Plugins.
