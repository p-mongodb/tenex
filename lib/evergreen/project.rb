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

    def owner_name
      info.fetch('owner_name')
    end

    def repo_name
      info.fetch('repo_name')
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

    def vars
      info['variables']['vars']
    end

    def private_vars
      info['variables']['private_vars']
    end

    def pr_testing_enabled?
      info.fetch('pr_testing_enabled')
    end

    def admins
      info.fetch('admins')
    end

    def recent_patches
      begin
        payload = client.get_json("projects/#{id}/patches")
      rescue NotFound => e
        # Evergreen returns 404 when the route is valid but there are no
        # patches: https://jira.mongodb.org/browse/EVG-5840
        # There used to be text "no patches found" in the response body that
        # we could use to detect this condition, but it appears to be gone now.
        # Hit the project endpoint to verify the project id is valid.
        begin
          client.get_json("projects/#{id}")
        rescue NotFound
          # project id likely invalid, raise original exception
          raise e
        end
=begin
        unless e.message =~ /no patches found/
          raise
        end
=end
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
