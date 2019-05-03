autoload :JSON, 'json'
require 'faraday'
require 'faraday/detailed_logger'

module Confluence

  class Client

    class ApiError < StandardError
      def initialize(message, status: nil)
        super(message)
        @status = status
      end

      attr_reader :status
    end

    def initialize(username:, password:, site:, auth_token:)
      @connection ||= Faraday.new("#{site}/rest/api") do |f|
        f.request :url_encoded
        f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        f.headers['cookie'] = "auth_user=#{username}; auth_token=#{auth_token}"
        f.basic_auth(username, password)
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
        if response.headers['location']
          msg += " to #{response.headers['location']}"
        end
        if error
          msg += ": #{error}"
        end
        raise ApiError.new(msg, status: response.status)
      end
      JSON.parse(response.body)
    end

    # endpoints

    def find_page_by_space_and_title(space, title)
      cql = %Q,space="#{space}" and title="#{title}",
      find_pages_by_cql(cql).first
    end

    def find_pages_by_cql(cql)
      payload = get_json("content/search?cql=#{URI.encode(cql)}")
      payload['results']
    end
  end
end
