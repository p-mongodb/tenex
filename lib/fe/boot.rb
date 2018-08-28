require 'dotenv'
require 'byebug'
require 'mongoid'

Dotenv.load

Mongoid.load!(File.join(File.dirname(__FILE__), '..', '..', 'config', 'mongoid.yml'))

require 'github'
require 'evergreen'

Dir['./lib/fe/models/**/*.rb'].each do |path|
  require_relative path.sub('/lib/fe/', '/').sub('.rb', '')
end

require_relative './system'
require_relative './toolchain'
require_relative './repo_cache'
