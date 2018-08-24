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
      query['text'] = 'true'
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
  end
end
