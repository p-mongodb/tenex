autoload :JSON, 'json'
require_relative '../paginated_get'
require 'faraday'
require 'faraday/detailed_logger'

module Github
  class Client

    class ApiError < StandardError
      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end

      attr_reader :status, :body
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
      request_json(:get, url)
    end

    def post_json(url, params, headers: nil)
      request_json(:post, url, params: params, headers: headers)
    end

    def request_json(meth, url, params: nil, headers: nil)
      response = connection.send(meth) do |req|
        req.url(url)
        if params
          req.body = JSON.dump(params)
          req.headers['content-type'] = 'application/json'
        end
        if headers
          headers.each do |k, v|
            req.headers[k] = v
          end
        end
      end
      if response.status != 200 && response.status != 201
        error = nil
        begin
          payload = JSON.parse(response.body)
          error = payload['error'] || payload['message']
        rescue
        end
        msg = "Github #{meth.to_s.upcase} #{url} failed: #{response.status}"
        if error
          msg += ": #{error}"
        end
        raise ApiError.new(msg, status: response.status, body: response.body)
      end
      JSON.parse(response.body)
    end

    def repo(user_name, repo_name)
      Repo.new(self, user_name, repo_name)
    end

    def create_pr(org_name, repo_name, title:, body:,
      head:, base: 'master'
    )
      post_json("/repos/#{org_name}/#{repo_name}/pulls",
        {title: title, head: head, base: base,
        body: body, draft: false},
        headers: {'accept' => 'application/vnd.github.shadow-cat-preview'})
    end

    def create_gist(payload)
      post_json('/gists', payload)
    end
  end
end
