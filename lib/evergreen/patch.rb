module Evergreen
  class Patch
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id, :info

    def description
      if info['description'] && !info['description'].empty?
        info['description']
      else
        "Patch #{info['patch_number']} by #{info['author']}"
      end
    end

    def version_id
      version_id = info['version']
      if version_id == ''
        version_id = nil
      end
      version_id
    end

    def version
      if version_id.nil?
        raise ArgumentError, "Cannot obtain version when version_id is nil (for patch #{id})"
      end
      client.version_by_id(version_id)
    end

    def authorize!
      client.patch_json("patches/#{id}", activated: true)
    end
  end
end
