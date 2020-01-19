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

    def created_at
      info['create_time'] && Time.parse(info['create_time'])
    end

    def started_at
      info['start_time'] && Time.parse(info['start_time'])
    end

    def finished_at
      info['finish_time'] && Time.parse(info['finish_time'])
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
        body = resp.body
        if content_type = resp.headers['content-type']
          if content_type =~ /charset=utf-8/i
            body.force_encoding('utf-8')
          end
        end
        body
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

    def finished?
      %w(success failed).include?(status)
    end

    # Returns expected duration of running task
    def expected_duration
      task = tasks.detect(&:running?)
      task&.expected_duration
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

    def detect_artifact(name)
      unless tasks.count == 1
        raise "Build has #{tasks.count} tasks, need 1"
      end
      task = tasks.first
      task.artifacts.detect do |artifact|
        artifact.name == name
      end
    end

    def detect_artifact!(name)
      detect_artifact(name).tap do |artifact|
        if artifact.nil?
          raise "Could not find artifact: #{name}"
        end
      end
    end
  end
end
