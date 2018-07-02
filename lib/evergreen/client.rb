require 'faraday'
require 'link_header'
require_relative '../paginated_get'

module Evergreen
  class Client
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
      JSON.parse(response.body)
    end

    def projects
      payload = paginated_get('projects')
      projects = payload.map { |info| Project.new(self, info['identifier'], info: info) }
      projects.sort_by { |project| project.display_name }
    end
  end
end
