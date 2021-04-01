module Evergreen
  class BuildloggerClient
    include ClientMethods

    def initialize(username:, api_key:, cache_root: nil)
      @username = username
      @api_key = api_key
      @connection ||= Faraday.new('https://cedar.mongodb.com/rest/v1/buildlogger') do |f|
        #f.request :url_encoded
        #f.response :detailed_logger
        f.adapter Faraday.default_adapter
        f.headers['user-agent'] = 'EvergreenRubyClient'
        # These work:
        f.headers['evergreen-api-user'] = username
        f.headers['evergreen-api-key'] = api_key
        # These are documented in
        # https://github.com/evergreen-ci/cedar/wiki/Rest-V1-Usage
        # but do not work:
        #f.headers['api-user'] = username
        #f.headers['api-key'] = api_key
      end
      @cache_root = cache_root
    end

    def task_log(task_id)
      # task_log | agent_log | system_log
      # https://jira.mongodb.org/browse/EVG-12398 or
      # https://jira.mongodb.org/browse/EVG-13478
      #connection.get("task_id/#{task_id}?proc_name=task_log&print_time=true&print_priority=true").body
      resp = nil
      10.times do
        # tags indicate which logs are desired: agent_log,task_log,system_log
        resp = connection.get("task_id/#{task_id}?tags=task_log&print_priority=true&print_time=true")
        # This returns task and agent logs together with no formatting
        # or any other means of telling which line comes from where:
        #resp = connection.get("task_id/#{task_id}")
        if resp.status == 200
          break
        elsif resp.status == 500 && resp.body =~ /service unavailable/i
          # retry
        else
          raise ApiError, "Bogus response: #{resp.status}: #{resp.body}"
        end
      end
      resp.body
    end

  end
end
