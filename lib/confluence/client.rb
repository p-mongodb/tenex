autoload :Oj, 'oj'
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

    def initialize(site:, username: nil, password: nil, auth_token: nil, cookies: nil)
      if username && !password  || password && !username
        raise ArgumentError, 'Username and password must be given together'
      end
      if auth_token && !username
        raise ArgumentError, 'Auth token requires username'
      end

      @connection ||= Faraday.new("#{site}/rest/api") do |f|
        f.request :url_encoded
        f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        if username
          if auth_token
            f.headers['cookie'] = "auth_user=#{username}; auth_token=#{auth_token}"
          end
          f.basic_auth(username, password)
        end
        if cookies
          hv = cookies.map { |k, v| "#{k}=#{v}" }.join('; ')
          p hv
          f.headers['cookie'] = hv
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
          req.body = Oj.dump(params)
          req.headers['content-type'] = 'application/json'
        end
      end
      if response.status == 204
        return nil
      end
      unless [200, 201].include?(response.status)
        error = nil
        begin
          error = Oj.load(response.body)['message']
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
      Oj.load(response.body)
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

    def get_page(id)
      payload = get_json("content/#{id}?expand=body.editor,body.storage,version,space")
    end

    def update_page(id, payload)
      request_json(:put, "content/#{id}", payload)
    end
  end
end
