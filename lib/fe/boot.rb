require 'dotenv'
require 'byebug'
require 'mongoid'

Dotenv.load

Mongoid.load!(File.join(File.dirname(__FILE__), '..', '..', 'config', 'mongoid.yml'))

autoload :Github, 'github'
autoload :Evergreen, 'evergreen'

Dir['./lib/fe/models/**/*.rb'].each do |path|
  sym = File.basename(path).sub('.rb', '').camelize
  autoload sym, path.sub(%r,^./lib/,, '').sub('.rb', '')
end

autoload :System, 'fe/system'
autoload :Toolchain, 'fe/toolchain'
autoload :RepoCache, 'fe/repo_cache'
