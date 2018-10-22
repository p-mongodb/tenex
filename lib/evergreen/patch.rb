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

    def version
      info['version']
    end

    def authorize!
      client.patch_json("patches/#{id}", activated: true)
    end
  end
end
