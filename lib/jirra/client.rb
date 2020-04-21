autoload :JSON, 'json'
require 'faraday'
require 'faraday/detailed_logger'
require 'oauthenticator'

module Jirra

  class TransitionNotFound < StandardError; end

  class Client

    class ApiError < StandardError
      def initialize(message, status: nil)
        super(message)
        @status = status
      end

      attr_reader :status
    end

    def initialize(
      site:,
      username: nil, password: nil,
      oauth_access_token: nil, oauth_access_token_secret: nil,
      oauth_consumer_key: nil, oauth_consumer_secret: nil,
      oauth_signature_method: nil
    )
      signing_options = {
        signature_method: oauth_signature_method,
        consumer_key: oauth_consumer_key,
        consumer_secret: oauth_consumer_secret,
        token: oauth_access_token,
        token_secret: oauth_access_token_secret,
        realm: site,
      }
      @connection ||= Faraday.new("#{site}/rest/api/latest") do |f|
        f.request :url_encoded
        f.response :detailed_logger
        if ENV['JIRA_ACCESS_TOKEN']
          f.request :oauthenticator_signer, signing_options
        end
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        if username && password
          f.basic_auth(username, password)
        end
      end
    end

    attr_reader :connection

    def get_json(url)
      request_json(:get, url)
    end

    def post_json(url, params=nil)
      request_json(:post, url, params)
    end

    def request_json(meth, url, params=nil)
      response = connection.send(meth) do |req|
        req.url(url)
        if params
          req.body = JSON.dump(params)
          req.headers['content-type'] = 'application/json'
        end
      end
      if response.status == 204
        return nil
      end
      unless [200, 201].include?(response.status)
        error = nil
        begin
          payload = JSON.parse(response.body)
          error = payload['error']
          if payload['errorMessages']
            error ||= payload['errorMessages'].join(', ')
          end
        rescue
        end
        msg = "Jira #{meth.to_s.upcase} #{url} failed: #{response.status}"
        if error
          msg += ": #{error}"
        end
        raise ApiError.new(msg, status: response.status)
      end
      JSON.parse(response.body)
    end

    # endpoints

    def get_issue_fields(issue_key, fields: nil)
      url = "issue/#{issue_key.upcase}?"
      if fields
        url << "&fields=#{fields.map { |f| CGI.escape(f) }.join(',')}"
      end
      get_json(url)['fields']
    end

    def get_issue_editmeta(issue_key)
      get_json("issue/#{issue_key}/editmeta")
    end

    def get_issue_transitions(issue_key)
      get_json("issue/#{issue_key}/transitions")
    end

    def project_statuses(project_key)
      get_json("project/#{project_key}/statuses")
    end

    def project_versions(project_name)
      get_json("project/#{project_name}/versions").map do |info|
        Version.new(info: info)
      end.sort_by(&:name)
    end

    def transition_issue(issue_key, target_status_name, set_fields = {})
      # https://stackoverflow.com/questions/21738782/does-the-jira-rest-api-require-submitting-a-transition-id-when-transitioning-an
      # https://developer.atlassian.com/server/jira/platform/jira-rest-api-example-edit-issues-6291632/
      transitions = get_json("issue/#{issue_key}/transitions")
      transition = transitions['transitions'].detect do |tr|
        tr['name'] == target_status_name
      end

      if transition.nil?
        raise TransitionNotFound
      end

      transition_id = transition['id']

      payload = {
        fields: set_fields,
        transition: {
          id: transition_id,
        },
      }
      post_json("issue/#{issue_key}/transitions", payload)
    end

    def edit_issue(issue_key, add_labels: nil, set_fix_versions: nil)
      payload = {}
      if add_labels
        payload[:update] ||= {}
        payload[:update][:labels] ||= []
        add_labels.each do |label|
          payload[:update][:labels] << {add: label}
        end
      end
      if set_fix_versions
        payload[:update] ||= {}
        payload[:update][:fixVersions] = [{
          set: set_fix_versions.map { |name| { name: name } },
        }]
      end
      request_json(:put, "issue/#{issue_key}", payload)
    end

    def add_issue_link(issue_key, link_id: nil, url:, title:, icon: nil)
      # https://developer.atlassian.com/server/jira/platform/jira-rest-api-for-remote-issue-links/
      payload = {
        object: {
          url: url,
          title: title,
          status: {
            icon: {},
          },
        },
      }
      if link_id
        payload[:globalId] = link_id
      end
      if icon
        payload[:object][:icon] = icon
      end
      post_json("issue/#{issue_key}/remotelink", payload)
    end

    def subject_for_issue(issue_key)
      issue_fields = get_issue_fields(issue_key)
      summary = issue_fields['summary']
      type = issue_fields['issuetype']['name']
      subject = "#{issue_key} #{summary}"
      if type == 'Bug'
        subject = "Fix #{subject}"
      end
      subject
    end

    def jql(jql, max_results: nil, fields: nil)
      url = "search?jql=#{CGI.escape(jql)}"
      if max_results
        url << "&maxResults=#{CGI.escape(max_results.to_s)}"
      end
      if fields
        escaped_fields = fields.map { |f| CGI.escape(f) }.join(',')
        url << "&fields=#{escaped_fields}"
      end
      payload = get_json(url)
      payload['issues']
    end
  end

  autoload :Version, 'jirra/version'
end
