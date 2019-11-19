module Evergreen
  class Version
    def initialize(client, id, info: nil)
      if id.nil?
        raise ArgumentError, 'id cannot be nil'
      end
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("versions/#{id}")
    end

    def project_name
      info['project']
    end

    def builds
      @builds ||= begin
        payload = client.get_json("versions/#{id}/builds")
        if payload.is_a?(Hash)
          # https://jira.mongodb.org/browse/EVG-3696
          payload = [payload]
        end
        payload.map do |info|
          Build.new(client, info['id'] || info['_id'], info: info)
        end.sort_by do |build|
          build.build_variant
        end
      end
    end

    def restart_failed_builds
      self.builds.each do |build|
        if build.failed?
          build.restart
        end
      end
    end

    def restart_all_builds
      self.builds.each do |build|
        build.restart
      end
    end

    def tasks
      @tasks ||= begin
        payload = client.get_json("projects/#{project_name}/revisions/#{revision}/tasks?limit=5000")
        payload.map do |info|
          Task.new(client, info['id'] || info['task_id'], info: info)
        end
      end
    end

    # sha of the commit
    def revision
      info['revision']
    end

    def pr_info
      if @pr_info_parsed
        @pr_info
      else
        @pr_info_parsed = true
        @pr_info = begin
          if info['message'] =~ %r,'(.+?)/(.+?)' pull request #(\d+) by (.*): (.*),
            {owner_name: $1, repo_name: $2, pr_number: $3}
          else
            nil
          end
        end
      end
    end

    %w(message).each do |m|
      define_method(m) do
        info[m]
      end
    end

    def created_at
      # iso8601
      Time.parse(info['create_time'])
    end

    def abort
      client.post_json("versions/#{id}/abort")
    end
  end
end
