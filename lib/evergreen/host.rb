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

    def status
      info['status']
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

    # For spawn hosts, the MongoDB username of the user that started the host.
    def started_by
      info['started_by']
    end

    # login_user and host_type fields are only returned by the server once the
    # underlying AWS host is provisioned for user spawned hosts.
    # host_type is AWS instance type like c3.8xlarge.
    # user is the Unix login username, usually ec2-user or admin

    # The username of the user for SSH login to the host.
    def login_user
      info['user']
    end

    # Values seen: ec2-ondemand
    def host_type
      info['host_type']
    end

    def distro
      Distro.new(client, info['distro']['distro_id'])
    end

    # Whether the host is currently running a task that is part of an
    # Evergreen build. false for spawn hosts.
    def running_task?
      !!info['running_task']['task_id']
    end

    # Presumably this is true for spawn hosts (spawned by a user),
    # false by hosts spawned by Evergreen to run tasks.
    def user_host?
      !!info['user_host']
    end

    def started_at
      return nil unless info['instance_tags']
      tag = info['instance_tags'].detect { |tag| tag['key'] == 'start-time' }
      if tag
        # Sample value: 20200413161520 (close to iso8601 but not it).
        Time.parse(tag['value'])
      else
        nil
      end
    end

    # ----- Actions -----

    def terminate
      client.post_json("hosts/#{id}/terminate")
    end
  end
end
