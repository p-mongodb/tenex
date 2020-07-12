autoload :Curl, 'curb'

module Evergreen
  class Build
    class BodyTooLarge < StandardError; end

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

    def project_id
      info['project_id']
    end

    def version_id
      info['version']
    end

    def tasks
      @tasks ||= begin
        info['tasks'].map do |task_id|
          cached_info = info['task_cache']&.detect { |ti| ti['id'] == task_id }
          Task.new(client, task_id, cached_info: cached_info)
        end
      end
    end

    def created_at
      Utils.convert_time(info['create_time'])
    end

    def started_at
      Utils.convert_time(info['start_time'])
    end

    def finished_at
      Utils.convert_time(info['finish_time'])
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
        resp = client.get_raw(public_send("#{which}_log_url"))
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

      # Retrieves at most 10 mb of log data.
      # Evergreen provides no indication of how big the log is, and
      # simply closes the connection if any request takes over a minute.
      # Currently log transfer rate is about 1 mb/s, thus retrieve up to
      # 10 mb which should take about 10 seconds.
      # https://jira.mongodb.org/browse/EVG-12428
      define_method("sensible_#{which}_log") do
        curl = Curl::Easy.new(public_send("#{which}_log_url"))
        curl.headers['user-agent'] = 'EvergreenRubyClient'
        curl.headers['api-user'] = client.username
        curl.headers['api-key'] = client.api_key
        #curl.verbose = true

        status = nil
        headers = {}
        curl.on_header do |data|
          if status.nil?
            if data =~ %r,\AHTTP/[0-9.]+ (\d+) ,
              status = $1.to_i
              if status != 200
                raise "Failed to retrieve logs: status #{status} for #{url}"
              end
            end
          elsif data =~ /:/
            bits = data.split(':', 2)
            headers[bits.first.strip.downcase] = bits.last.strip
          end
          data.length
        end

        body = ''
        curl.on_body do |chunk|
          body += chunk
          if body.length > 10_000_000
            raise BodyTooLarge
          end
          chunk.length
        end

        begin
          curl.perform
          truncated = false
        rescue BodyTooLarge
          truncated = true
        end

        unless headers['content-type'] && headers['content-type'] =~ /charset=utf-8/i
          warn "Missing content-type or not in UTF-8"
        end

        # Assume UTF-8 anyway otherwise we can't regexp match downstream
        body.force_encoding('utf-8')

        [body, truncated]
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

    def activated?
      info['activated']
    end

    def order
      info['order']
    end

    # Returns expected duration of running task
    def expected_duration
      task = tasks.detect(&:running?)
      task&.expected_duration
    end

    def artifacts
      tasks.map(&:artifacts).flatten
    end

    def artifact(basename)
      artifact = artifacts.detect do |artifact|
        artifact.name == basename
      end
    end

    def artifact?(basename)
      !!artifact(basename)
    end

    # Returns the first artifact whose name is in the desired names list,
    # with the order of names in desired names defining the priority of
    # artifacts. This method assumes that all of the artifacts specified by
    # the desired names are produced by the same task, hence it can
    # simply delegate to Task#first_artifact_for_names.
    def first_artifact_for_names(desired_names)
      tasks.each do |task|
        artifact = task.first_artifact_for_names(desired_names)
        if artifact
          return artifact
        end
      end
      nil
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
