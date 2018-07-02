require 'faraday'

module Github
  class Client
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
      JSON.parse(response.body)
    end

    def repo(user_name, repo_name)
      Repo.new(self, user_name, repo_name)
    end
  end
end
