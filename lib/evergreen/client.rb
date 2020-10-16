autoload :Oj, 'oj'
require 'faraday'
require_relative '../paginated_get'
require 'active_support/core_ext/string'

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

    def initialize(username:, api_key:, cache_root: nil)
      @username = username
      @api_key = api_key
      @connection ||= Faraday.new('https://evergreen.mongodb.com/api') do |f|
        #f.request :url_encoded
        #f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        f.headers['api-user'] = username
        f.headers['api-key'] = api_key
      end
      @cache_root = cache_root
    end

    attr_reader :connection
    private :connection

    attr_reader :username
    attr_reader :api_key

    # Where various files are to be stored
    attr_reader :cache_root

    def get_raw(url)
      request(:get, url)
    end

    def request(meth, url)
      puts "EG: #{meth} #{url}"
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
      puts "EG: #{meth} #{url}"
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

    def projects
      @projects ||= begin
        payload = paginated_get('projects')
        projects = payload.map { |info| Project.new(self, info['identifier'], info: info) }
        projects.sort_by { |project| project.display_name }
      end
    end

    def project_by_id(id)
      payload = get_json("projects/#{id}")
      Project.new(self, payload['identifier'], info: payload)
    end

    def version_by_id(id)
      payload = get_json("versions/#{id}")
      Version.new(self, payload['version_id'], info: payload)
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

    def patch_by_id(id)
      payload = get_json("patches/#{id}")
      Patch.new(self, payload['patch_id'], info: payload)
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
      payload = get_json("hosts", limit: 100_000)
      payload.map do |info|
        Host.new(self, info['host_id'], info: info)
      end
    end

    def user_hosts
      payload = get_json("users/#{username}/hosts") || []
      payload.map do |info|
        Host.new(self, info['host_id'], info: info)
      end
    end

    def spawn_host(distro_name:, key_name:)
      payload = post_json('hosts', distro: distro_name, keyname: key_name)
      Host.new(self, payload['host_id'], info: payload)
    end

=begin
  The endpoint that create_patch uses is undocumented.
  As of this writing it replaced buildvariants with buildvariants_new key.

  Current structure:
        data := struct {
                Description       string             `json:"desc"`
                Project           string             `json:"project"`
                PatchBytes        []byte             `json:"patch_bytes"`
                Githash           string             `json:"githash"`
                Alias             string             `json:"alias"`
                Variants          []string           `json:"buildvariants_new"`
                Tasks             []string           `json:"tasks"`
                SyncTasks         []string           `json:"sync_tasks"`
                SyncBuildVariants []string           `json:"sync_build_variants"`
                SyncStatuses      []string           `json:"sync_statuses"`
                SyncTimeout       time.Duration      `json:"sync_timeout"`
                Finalize          bool               `json:"finalize"`
                BackportInfo      patch.BackportInfo `json:"backport_info"`
                Parameters        []patch.Parameter  `json:"parameters"`
        }{
                Description:       incomingPatch.description,
                Project:           incomingPatch.projectId,
                PatchBytes:        []byte(incomingPatch.patchData),
                Githash:           incomingPatch.base,
                Alias:             incomingPatch.alias,
                Variants:          incomingPatch.variants,
                Tasks:             incomingPatch.tasks,
                SyncBuildVariants: incomingPatch.syncBuildVariants,
                SyncTasks:         incomingPatch.syncTasks,
                SyncStatuses:      incomingPatch.syncStatuses,
                SyncTimeout:       incomingPatch.syncTimeout,
                Finalize:          incomingPatch.finalize,
                BackportInfo:      incomingPatch.backportOf,
                Parameters:        incomingPatch.parameters,
        }
=end
    def create_patch(project_id:, description: nil,
      diff_text:, base_sha:, variant_ids: %w(all), task_ids: %w(all),
      finalize: nil
    )
      resp = request_json(:put, 'patches/', {
        project: project_id,
        desc: description,
        patch_bytes: Base64.encode64(diff_text),
        githash: base_sha,
        buildvariants_new: variant_ids,
        tasks: task_ids,
        finalize: finalize,
      }, version: 1)

      if resp['message'] != ''
        byebug
        1
      end
      if resp['action'] != ''
        byebug
        1
      end

      patch_info = deep_underscore_keys(resp['patch'])
      Patch.new(self, patch_info['id'], info: patch_info)
    end

    private def deep_underscore_keys(hash)
      if hash.is_a?(Hash)
        Hash[hash.map { |k, v| [k.underscore, deep_underscore_keys(v)] }]
      else
        hash
      end
    end
  end
end
