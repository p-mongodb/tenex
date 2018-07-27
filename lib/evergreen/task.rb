module Evergreen
  class Task
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("tasks/#{id}")
    end

    def log_url
      info['logs']['task_log']
    end

    def log
      resp = client.connection.get(log_url)
      if resp.status != 200
        fail resp.status
      end
      resp.body
    end

    def display_name
      info['display_name']
    end

    def status
      info['status']
    end
  end
end
