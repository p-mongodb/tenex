require 'json'
require 'faraday'
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

    class NotFound < ApiError; end

    include PaginatedGet

    def initialize(username:, api_key:)
      @user_id = username
      @connection ||= Faraday.new('https://evergreen.mongodb.com/api') do |f|
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
        req.url(url)
        if params
          req.body = payload = JSON.dump(params)
          puts "Sending payload: #{payload} for #{url}"
          req.headers['content-type'] = 'application/json'
        end
      end
      if response.status != 200 && response.status != 201
        error = nil
        begin
          error = JSON.parse(response.body)['error']
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
      payload = get_json("/spawn/distros")
      payload.map do |info|
        Distro.new(self, info['name'], info: info)
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
        Host.new(self, info['host_id'], info: info)
      end
    end

    def user_hosts
      payload = get_json("users/#{user_id}/hosts") || []
      payload.map do |info|
        Host.new(self, info['host_id'], info: info)
      end
    end

    def spawn_host(distro_name:, key_name:)
      payload = post_json('hosts', distro: distro_name, keyname: key_name)
      Host.new(self, payload['host_id'], info: payload)
    end

    def create_patch(project_id:, description: nil,
      diff_text:, base_sha:, variant_ids: [], task_ids: [],
      finalize: nil
    )
      request_json(:put, 'patches/', {
        project: project_id,
        desc: description,
        patch: diff_text,
        githash: base_sha,
        buildvariants: variant_ids.join(','),
        tasks: task_ids,
        finalize: finalize,
      }, version: 1)
    end
  end
end
