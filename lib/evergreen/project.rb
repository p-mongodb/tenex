module Evergreen
  class Project
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def display_name
      if @info['display_name'] && !@info['display_name'].empty?
        @info['display_name']
      else
        @info['identifier']
      end
    end

    def recent_patches
      payload = client.get_json("projects/#{id}/patches?start_at=\"2020-01-01T00:00:00.000Z\"")
      payload.map do |info|
        Patch.new(client, info['patch_id'], info: info)
      end
    end

    def recent_versions
      payload = client.get_json("projects/#{id}/recent_versions")
      payload['versions'].map do |info|
        info = info['versions'].first
        Version.new(client, info['version_id'], info: info)
      end
    end
  end
end
