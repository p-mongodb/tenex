require_relative '../paginated_get'
require 'faraday'

module Github
  class Client

    class ApiError < StandardError
      def initialize(message, status: nil)
        super(message)
        @status = status
      end

      attr_reader :status
    end

    include PaginatedGet

    def initialize(username:, auth_token:)
      @connection ||= Faraday.new('https://api.github.com') do |f|
        f.request :url_encoded
        #f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        f.basic_auth(username, auth_token)
      end
    end

    attr_reader :connection

    def get_json(url)
      response = connection.get(url)
      if response.status != 200
        raise ApiError.new("Github GET #{url} failed: #{response.status}", status: response.status)
      end
      JSON.parse(response.body)
    end

    def repo(user_name, repo_name)
      Repo.new(self, user_name, repo_name)
    end
  end
end
