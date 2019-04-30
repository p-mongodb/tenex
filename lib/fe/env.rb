autoload :Jirra, 'jirra/client'
autoload :JIRA, 'jira-ruby'

module Env

  module_function def jira_client
    @jira_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
        :context_path => '',
        :auth_type    => :basic
      }

      JIRA::Client.new(options)
    end
  end

  module_function def jirra_client
    @jirra_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
      }

      ::Jirra::Client.new(options)
    end
  end

  module_function def confluence_client
    @confluence_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['CONFLUENCE_SITE'],
      }

      ::Confluence::Client.new(options)
    end
  end

  module Access
    %i(jira_client jirra_client confluence_client).each do |m|
      define_method(m) do
        Env.send(m)
      end
    end
  end

end
