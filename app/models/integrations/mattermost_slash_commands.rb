# frozen_string_literal: true

module Integrations
  class MattermostSlashCommands < BaseSlashCommands
    include Ci::TriggersHelper

    MATTERMOST_URL = '%{ORIGIN}/%{TEAM}/channels/%{CHANNEL}'

    field :token,
      type: :password,
      description: -> { _('The Mattermost token.') },
      non_empty_password_title: -> { s_('ProjectService|Enter new token') },
      non_empty_password_help: -> { s_('ProjectService|Leave blank to use your current token.') },
      required: true,
      placeholder: ''

    def testable?
      false
    end

    def self.title
      s_('Integrations|Mattermost slash commands')
    end

    def self.description
      s_('Integrations|Perform common tasks with slash commands.')
    end

    def self.to_param
      'mattermost_slash_commands'
    end

    def configure(user, params)
      token = ::Mattermost::Command.new(user)
        .create(command(params))

      update(active: true, token: token) if token
    rescue ::Mattermost::Error => e
      [false, e.message]
    end

    def list_teams(current_user)
      [::Mattermost::Team.new(current_user).all, nil]
    rescue ::Mattermost::Error => e
      [[], e.message]
    end

    def redirect_url(team, channel, url)
      return if Gitlab::UrlBlocker.blocked_url?(url, schemes: %w[http https], enforce_sanitization: true)

      origin = Addressable::URI.parse(url).origin
      format(MATTERMOST_URL, ORIGIN: origin, TEAM: team, CHANNEL: channel)
    end

    def confirmation_url(command_id, params)
      team, channel, response_url = params.values_at(:team_domain, :channel_name, :response_url)

      Rails.application.routes.url_helpers.project_integrations_slash_commands_url(
        project, command_id: command_id, integration: to_param, team: team, channel: channel, response_url: response_url
      )
    end

    private

    def command(params)
      pretty_project_name = project.full_name

      params.merge(
        auto_complete: true,
        auto_complete_desc: "Perform common operations on: #{pretty_project_name}",
        auto_complete_hint: '[help]',
        description: "Perform common operations on: #{pretty_project_name}",
        display_name: "GitLab / #{pretty_project_name}",
        method: 'P',
        username: 'GitLab')
    end
  end
end
