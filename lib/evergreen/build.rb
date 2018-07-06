module Evergreen
  class Build
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("builds/#{id}")
    end

    def tasks
      @tasks ||= begin
        info['tasks'].map do |task|
          Task.new(client, task)
        end
      end
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
      if resp.status != 200
        fail resp.status
      end
      resp.body
    end

    def restart
      info['tasks'].each do |task_id|
        resp = client.connection.post("tasks/#{task_id}/restart")
        puts resp.status
      end
    end

    def failed?
      info['status'] == 'failed'
    end

    def build_variant
      info['build_variant']
    end

    def status
      info['status']
    end
  end
end
