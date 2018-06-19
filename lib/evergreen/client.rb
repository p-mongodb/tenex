require 'faraday'

module Evergreen
  class Client
    def initialize(username:, api_key:)
      @connection ||= Faraday.new('https://evergreen.mongodb.com/api/rest/v2') do |f|
        #f.request :url_encoded
        #f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        f.headers['auth-username'] = username
        f.headers['api-key'] = api_key
      end
    end

    attr_reader :connection

    def get_json(url)
      response = connection.get(url)
      JSON.parse(response.body)
    end
  end
end
