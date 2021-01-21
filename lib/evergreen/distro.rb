module Evergreen

  class Distro
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def aliases
      info.fetch('aliases')
    end

    def info
      @info ||= begin
        # there is no distros/:id route.
        # get full list of distros and filter down manually
        payload = client.get_json('/spawn/distros')
        payload.detect do |info|
          info['name'] == id
        end.tap do |info|
          if info.nil?
            raise DistroNotFound, "Cannot retrieve distro information for #{id}"
          end
        end
      end
    end

    alias name id

    def <=>(other)
      if other.is_a?(Distro)
        id <=> other.id
      else
        raise ArgumentError, "Cannot compare a distro with #{other}"
      end
    end
  end
end
