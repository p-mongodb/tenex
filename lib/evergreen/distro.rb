module Evergreen
  class Distro
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("tasks/#{id}")
    end

    %w(name user_spawn_allowed provider image_id).each do |m|
      define_method(m) do
        info[m]
      end
    end
  end
end
