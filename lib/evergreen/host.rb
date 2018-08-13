module Evergreen
  class Host
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("hosts/#{id}")
    end

    %w(host_url provisioned started_by host_type user status user_host).each do |m|
      define_method(m) do
        info[m]
      end
    end

    def distro
      Distro.new(client, info['distro']['distro_id'])
    end

    def terminate
      client.post_json("hosts/#{id}/terminate")
    end
  end
end
