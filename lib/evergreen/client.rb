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
      @user_id = username
      @connection ||= Faraday.new('https://evergreen.mongodb.com/api/rest/v2') do |f|
        #f.request :url_encoded
        #f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        f.headers['api-user'] = username
        f.headers['api-key'] = api_key
      end
    end

    attr_reader :connection, :user_id

    def get_json(url)
      request_json(:get, url)
    end

    def post_json(url, params)
      request_json(:post, url, params)
    end

    def request_json(meth, url, params=nil)
      response = connection.send(meth) do |req|
        req.url(url)
        if params
        p params
          req.body = JSON.dump(params)
        end
      end
      if response.status != 200
        error = nil
        begin
          error = JSON.parse(response.body)['error']
        rescue
        end
        msg = "Evergreen #{meth.to_s.upcase} #{url} failed: #{response.status}"
        if error
          msg += ": #{error}"
        end
        raise ApiError.new(msg, status: response.status)
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
        rescue URI::InvalidURIError, ApiError => e
          puts "Error retrieving recent patches for #{project.id}: #{e}"
        end
      end
      nil
    end

    def distros
      payload = get_json("distros")
      payload.map do |info|
        Distro.new(self, info['id'], info: info)
      end
    end

    def keys
      payload = get_json("keys")
      payload.map do |info|
        Key.new(self, info['id'], info: info)
      end
    end

    def hosts
      payload = get_json("hosts")
      payload.map do |info|
        Host.new(self, info['id'], info: info)
      end
    end

    def user_hosts
      payload = get_json("users/#{user_id}/hosts")
      payload.map do |info|
        Host.new(self, info['id'], info: info)
      end
    end

    def spawn_host(distro_name:, key_name:)
      payload = post_json('hosts', distro: distro_name, keyname: key_name)
      Host.new(self, payload['host_id'], info: payload)
    end
  end
end
