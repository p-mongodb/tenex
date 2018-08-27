require 'dotenv'
require 'byebug'
require 'mongoid'

Dotenv.load

Mongoid.load!(File.join(File.dirname(__FILE__), '..', '..', 'config', 'mongoid.yml'))

require 'github'
require 'evergreen'

require_relative './models'
require_relative './system'
require_relative './toolchain'
require_relative './repo'
