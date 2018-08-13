module Evergreen
  class Distro
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= begin
        # there is no distros/:id route.
        # get full list of distros and filter down manually
        payload = client.get_json('distros')
        info = payload.detect do |info|
          info['name'] == id
        end
      end
    end

    %w(name user_spawn_allowed provider image_id).each do |m|
      define_method(m) do
        info[m]
      end
    end
  end
end
