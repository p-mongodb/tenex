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
        f.headers['evergreen-api-user'] = username
        f.headers['evergreen-api-key'] = api_key
      end
      @cache_root = cache_root
    end

    def task_log(task_id)
      # task_log | agent_log | system_log
      # https://jira.mongodb.org/browse/EVG-12398 or
      # https://jira.mongodb.org/browse/EVG-13478
      #connection.get("task_id/#{task_id}?proc_name=task_log&print_time=true&print_priority=true").body
      connection.get("task_id/#{task_id}?proc_name=task_log").body
    end

  end
end
