require 'active_support/concern'

module Evergreen
  module ClientMethods
    extend ActiveSupport::Concern

    included do
      attr_reader :connection
      private :connection

      attr_reader :username
      attr_reader :api_key

      # Where various files are to be stored
      attr_reader :cache_root
    end

    def get_raw(url)
      request(:get, url)
    end

    def request(meth, url)
      STDERR.puts "EG: #{meth} #{url}"
      connection.send(meth, url)
    end

    def get_json(url, params=nil)
      request_json(:get, url, params)
    end

    def post_json(url, params=nil)
      request_json(:post, url, params)
    end

    def put_json(url, params=nil)
      request_json(:put, url, params)
    end

    def patch_json(url, params=nil)
      request_json(:patch, url, params)
    end

    def request_json(meth, url, params=nil, options={})
      STDERR.puts "EG: #{meth} #{url}"
      unless url.start_with?('/')
        case options[:version]
        when 1
        when nil, 2
          url = "rest/v2/#{url}"
        else
          raise ArgumentError, "Unknown version #{options[:version]}"
        end
      end
      response = connection.send(meth) do |req|
        if meth.to_s.downcase == 'get'
          if params
            u = URI.parse(url)
            query = u.query
            if query
              query = Rack::Utils.parse_nested_query(query)
            else
              query = {}
            end
            query.update(params)
            u.query = Rack::Utils.build_query(query)
            url = u.to_s
            params = nil
          end
        end
        req.url(url)
        if params
          req.body = payload = Oj.dump(params)
          puts "Sending payload: #{payload} for #{url}"
          req.headers['content-type'] = 'application/json'
        end
      end
      if response.status != 200 && response.status != 201
        error = nil
        begin
          error = Oj.load(response.body)['error']
        rescue
          error = response.body
        end
        msg = "Evergreen #{meth.to_s.upcase} #{url} failed: #{response.status}"
        if error
          msg += ": #{error}"
        end
        cls = if response.status == 404
          NotFound
        else
          ApiError
        end
        raise cls.new(msg, status: response.status)
      end
      Oj.load(response.body)
    end
  end
end
