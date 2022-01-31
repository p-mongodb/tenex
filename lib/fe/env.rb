module Evergreen
  autoload :Client, 'evergreen/client'
end

autoload :Jirra, 'jirra/client'
autoload :Confluence , 'confluence/client'
autoload :JIRA, 'jira-ruby'

#OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

module Env

  module_function def jira_client
    @jira_client ||= begin
      options = {
        :site         => ENV['JIRA_SITE'],
        signature_method: 'RSA-SHA1',
        private_key_file: ENV['JIRA_CONSUMER_SECRET'],
        consumer_key: ENV['JIRA_CONSUMER_KEY'],
        consumer_secret: ENV['JIRA_CONSUMER_SECRET'],
        :context_path => '',
        :auth_type    => :oauth,
      }

      JIRA::Client.new(**options).tap do |client|
        client.set_access_token(
          ENV['JIRA_ACCESS_TOKEN'],
          ENV['JIRA_ACCESS_TOKEN_SECRET'],
        )
      end
    end
  end

  module_function def jirra_client
    @jirra_client ||= begin
      options = {
        oauth_access_token: ENV['JIRA_ACCESS_TOKEN'],
        oauth_access_token_secret: ENV['JIRA_ACCESS_TOKEN_SECRET'],
        oauth_consumer_key: ENV['JIRA_CONSUMER_KEY'],
        oauth_consumer_secret: ENV['JIRA_CONSUMER_SECRET'],
        oauth_signature_method: 'RSA-SHA1',
        :site         => ENV['JIRA_SITE'],
      }

      ::Jirra::Client.new(**options)
    end
  end

  module_function def confluence_client
    @confluence_client ||= begin
      if ENV['CONFLUENCE_AUTH_TOKEN']
        auth_token = ENV['CONFLUENCE_AUTH_TOKEN']
      elsif ENV['CONFLUENCE_COOKIES_URL'] && !ENV['CONFLUENCE_COOKIES_URL'].empty?
        cookies_url = ENV['CONFLUENCE_COOKIES_URL']
        require 'open-uri'
        cookies = JSON.parse(open(ENV.fetch('CORP_COOKIES_URL')).read)
        #cookies.update(JSON.parse(open(cookies_url).read))
      else
        raise "No auth token mechanism defined"
      end

      options = {
        #username: empty_to_nil(ENV['JIRA_USERNAME']),
        #password: empty_to_nil(ENV['JIRA_PASSWORD']),
        site: ENV['CONFLUENCE_SITE'],
        #auth_token: auth_token,
        cookies: cookies,
      }

      ::Confluence::Client.new(options)
    end
  end

  module_function def empty_to_nil(str)
    if str && str.empty?
      nil
    else
      str
    end
  end

  module_function def gh_client
    @gh_client ||= Github::Client.new(
        username: ENV['GITHUB_USERNAME'],
        auth_token: ENV['GITHUB_TOKEN'],
      )
  end

  module_function def eg_client
    @eg_client ||= Evergreen::Client.new(
        username: ENV['EVERGREEN_AUTH_USERNAME'],
        api_key: ENV['EVERGREEN_API_KEY'],
        cache_root: File.join(File.dirname(__FILE__), '../../tmp/eg'),
      )
  end

  module_function def system_fe
    @system_fe ||= System.new(eg_client, gh_client)
  end

  module Access
    %i(
      jira_client jirra_client confluence_client gh_client eg_client system_fe
    ).each do |m|
      define_method(m) do
        Env.send(m)
      end
    end
  end

end
