require 'fe/boot_lite'

require 'mongoid'

mongoid_config_path = File.join(File.dirname(__FILE__), '..', '..', 'config', 'mongoid.yml')
if File.exist?(mongoid_config_path)
  Mongoid.load!(mongoid_config_path, ENV['RACK_ENV'] || 'development')
elsif mongodb_uri = ENV['MONGODB_URI']
  if mongodb_uri.empty?
    raise "MONGODB_URI cannot be empty"
  end
  Mongoid.configure do |config|
    config.clients.default = {
      uri: mongodb_uri,
    }
  end
else
  raise "No `config/mongoid.yml` and no MONGODB_URI set in environment, cannot figure out how to connect to MongoDB"
end

Dir['./lib/fe/models/**/*.rb'].each do |path|
  sym = File.basename(path).sub('.rb', '').camelize
  autoload sym, path.sub(%r,^./lib/,, '').sub('.rb', '')
end

autoload :System, 'fe/system'
autoload :Toolchain, 'fe/toolchain'
autoload :RepoCache, 'fe/repo_cache'

autoload :ResultFetcher, 'fe/workers/result_fetcher'
