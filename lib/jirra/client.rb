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
          error = JSON.parse(response.body)['error']
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

    def get_issue_fields(issue_key)
      get_json("issue/#{issue_key.upcase}")['fields']
    end

    def project_versions(project_name)
      get_json("project/#{project_name}/versions").sort_by do |version|
        version['name']
      end
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
  end
end
