module Evergreen
  class Build
    def initialize(client, id, info: nil)
      if id.nil?
        raise ArgumentError, 'nil build id'
      end
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

    %i(task all).each do |which|
      define_method("#{which}_log_url") do
        if info['tasks'].length != 1
          raise "Have #{info['tasks'].length} tasks, expecting 1"
        end

        task_id = info['tasks'].first

        task_info = client.get_json("tasks/#{task_id}")
        task_info['logs']["#{which}_log"]
      end

      define_method("#{which}_log") do
        resp = client.connection.get(send("#{which}_log_url"))
        if resp.status != 200
          fail resp.status
        end
        resp.body
      end
    end

    def restart
      resp = client.post_json("builds/#{id}/restart")
    end

    def failed?
      info['status'] == 'failed'
    end

    def running?
      info['status'] == 'started'
    end

    def waiting?
      info['status'] == 'created'
    end

    def build_variant
      info['build_variant']
    end

    def status
      info['status']
    end

    def completed?
      %w(success failed).include?(status)
    end

    def artifacts
      tasks.map(&:artifacts)
    end

    def artifact(basename)
      task = tasks.first
      artifact = task.artifacts.detect do |artifact|
        artifact.name == basename
      end
    end

    def artifact?(basename)
      task = tasks.first
      artifact = task.artifacts.detect do |artifact|
        artifact.name == basename
      end
      !!artifact
    end

    # in seconds
    def time_taken
      info['time_taken_ms'] / 1000.0
    end

    def started_at
      Time.parse(info['start_time'])
    end
  end
end
