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

    def task_log_html_url
      info['logs']['task_log']
    end

    def task_log_html
      resp = client.connection.get(task_log_html_url)
      if resp.status != 200
        fail resp.status
      end
      resp.body
    end

    def task_log_url
      uri = URI.parse(info['logs']['task_log'])
      query = CGI.parse(uri.query)
      #query['text'] = 'true'
      uri.query = URI.encode_www_form(query)
      uri.to_s
    end

    def task_log
      resp = client.connection.get(task_log_url)
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

    def waiting?
      %w(undispatched).include?(status)
    end

    def completed?
      %w(success failed).include?(status)
    end

    def failed?
      %w(failed).include?(status)
    end

    def priority
      info['priority']
    end

    def set_priority(priority)
      client.patch_json("tasks/#{id}", priority: priority)
    end

    def artifacts
      (info['artifacts'] || []).map { |artifact| Artifact.new(client, info: artifact) }
    end

    # in seconds
    def time_taken
      info['time_taken_ms'] / 1000.0
    end

    def self.normalize_status(status)
      map = {'failure' => 'failed', 'success' => 'passed', 'pending' => 'pending'}
      map[status].tap do |v|
        if v.nil?
          raise "No map entry for #{status['state']}"
        end
      end
    end

    def normalized_status
      self.class.normalize_status(status)
    end

    def restart
      resp = client.post_json("tasks/#{id}/restart")
    end
  end
end
