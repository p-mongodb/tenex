require 'faraday'
require 'link_header'
require_relative '../paginated_get'

module Evergreen
  class Client
    class ApiError < StandardError
      def initialize(message, status: nil)
        super(message)
        @status = status
      end

      attr_reader :status
    end

    include PaginatedGet

    def initialize(username:, api_key:)
      @connection ||= Faraday.new('https://evergreen.mongodb.com/api/rest/v2') do |f|
        #f.request :url_encoded
        #f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        f.headers['api-user'] = username
        f.headers['api-key'] = api_key
      end
    end

    attr_reader :connection

    def get_json(url)
      response = connection.get(url)
      if response.status != 200
        raise ApiError.new("Evergreen GET #{url} failed: #{response.status}", status: response.status)
      end
      JSON.parse(response.body)
    end

    def projects
      @projects ||= begin
        payload = paginated_get('projects')
        projects = payload.map { |info| Project.new(self, info['identifier'], info: info) }
        projects.sort_by { |project| project.display_name }
      end
    end

    def project_for_github_repo(owner_name, repo_name)
      projects.each do |project|
        begin
          patch = project.recent_patches.detect do |patch|
            patch.description =~ /^'#{owner_name}\/#{repo_name}' pull request/
          end
          if patch
            return project
          end
        rescue ApiError
        end
      end
      nil
    end
  end
end
