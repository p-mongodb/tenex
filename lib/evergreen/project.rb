module Evergreen
  class Project
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("projects/#{id}")
    end

    def display_name
      if info['display_name'] && !@info['display_name'].empty?
        info['display_name']
      else
        info['identifier']
      end
    end

    def branch_name
      info['branch_name']
    end

    def recent_patches
      begin
        payload = client.get_json("projects/#{id}/patches")
      rescue Client::NotFound => e
        unless e.message =~ /no patches found/
          raise
        end
        payload = []
      end
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

    def update(attributes)
      client.patch_json("projects/#{id}", attributes)
    end

    def admin_usernames
      # Sometimes admins is an array, sometimes it is null.
      # https://jira.mongodb.org/browse/EVG-6598
      info['admins'] || []
    end
  end
end
