require 'dotenv'
require 'byebug'

Dotenv.load(File.join(File.dirname(__FILE__), '../../.env'))

if ENV['JIRA_PASSWORD_PREFIX']
  suffix = Time.now.month
  if suffix > 9
    suffix = 'a'.ord + suffix - 10
  else
    suffix = '0'.ord + suffix
  end
  suffix = suffix.chr
  ENV['JIRA_PASSWORD'] = ENV['JIRA_PASSWORD_PREFIX'] + suffix
end

autoload :Github, 'github'
autoload :Evergreen, 'evergreen'
