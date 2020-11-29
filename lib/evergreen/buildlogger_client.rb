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
      connection.get("task_id/#{task_id}").body
    end

  end
end
