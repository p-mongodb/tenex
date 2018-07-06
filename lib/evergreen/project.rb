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
      payload = client.get_json("projects/#{id}/patches")
      payload.map do |info|
        Patch.new(client, info['patch_id'], info: info)
      end
    end
  end
end
