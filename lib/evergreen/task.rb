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

    def ui_url
      "https://evergreen.mongodb.com/task/#{id}"
    end

    %w(task agent system all).each do |kind|
      define_method("#{kind}_log_html_url") do
        info['logs']["#{kind}_log"]
      end

      define_method("#{kind}_log_html") do
        resp = client.connection.get(send("#{kind}_log_html_url"))
        if resp.status != 200
          fail resp.status
        end
        resp.body
      end

      define_method("#{kind}_log_url") do
        uri = URI.parse(info['logs']["#{kind}_log"])
        query = CGI.parse(uri.query)
        #query['text'] = 'true'
        uri.query = URI.encode_www_form(query)
        uri.to_s
      end

      define_method("#{kind}_log") do
        resp = client.connection.get(send("#{kind}_log_url"))
        if resp.status != 200
          fail resp.status
        end
        resp.body
      end
    end

    %w(display_name status build_id).each do |m|
      define_method(m) do
        info[m]
      end
    end

    {
      created_at: 'create_time',
      ingested_at: 'ingest_time',
      scheduled_at: 'scheduled_time',
      dispatched_at: 'dispatch_time',
      started_at: 'start_time',
      finished_at: 'finish_time',
    }.each do |m, key|
      define_method(m) do
        v = info[key]
        if v
          Time.parse(v)
        else
          nil
        end
      end
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
      map = {'failure' => 'failed', 'success' => 'passed', 'pending' => 'pending',
        'failed' => 'failed', 'undispatched' => 'waiting', 'started' => 'running'}
      map[status].tap do |v|
        if v.nil?
          raise "No map entry for #{status}"
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
