module Evergreen
  # host_id on user spawned hosts changes when the hosts provision:
  # https://jira.mongodb.org/browse/EVG-5184
  # response schema also changes depending on the state of the host
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

    %w(started_by host_type user status user_host).each do |m|
      define_method(m) do
        info[m]
      end
    end

    def address
      if value = info['host_url']
        if value == ''
          nil
        else
          value
        end
      else
        nil
      end
    end

    def distro_id
      info['distro']['distro_id']
    end

    def provisioned?
      info['provisioned']
    end

    # these fields are only returned by the server once the underlying
    # AWS host is provisioned for user spawned hosts.
    # host_type is AWS instance type like c3.8xlarge.
    # user is the Unix login username, usually ec2-user or admin
    %w(host_type user).each do |m|
      define_method(m) do
        info[m]
      end
    end

    def distro
      Distro.new(client, info['distro']['distro_id'])
    end

    def running_task?
      !!info['running_task']['task_id']
    end

    def terminate
      client.post_json("hosts/#{id}/terminate")
    end
  end
end
