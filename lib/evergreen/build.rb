module Evergreen
  class Build
    def initialize(client, id)
      @client = client
      @id = id
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("builds/#{id}")
    end

    def log_url
      if info['tasks'].length != 1
        raise "Have #{info['tasks'].length} tasks, expecting 1"
      end

      task_id = info['tasks'].first

      task_info = client.get_json("tasks/#{task_id}")
      task_info['logs']['all_log']
    end

    def log
      resp = client.connection.get(log_url)
      resp.body
    end
  end
end
