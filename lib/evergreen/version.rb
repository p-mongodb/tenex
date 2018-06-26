module Evergreen
  class Version
    def initialize(client, id)
      @client = client
      @id = id
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("versions/#{id}")
    end

    def builds
      payload = client.get_json("versions/#{id}/builds")
      payload.map do |info|
        Build.new(client, info['id'], info: info)
      end
    end

    def restart_failed_builds
      self.builds.each do |build|
        if build.failed?
          build.restart
        end
      end
    end

    def tasks
      payload = client.get_json("versions/#{id}/tasks")
      payload.map do |info|
        Task.new(client, info['id'], info: info)
      end
    end

    def revision
      Revision.new(client, info['revision'])
    end
  end
end
