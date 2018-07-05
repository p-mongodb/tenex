require 'dotenv'
require 'byebug'
require 'mongoid'

Dotenv.load

Mongoid.load!(File.join(File.dirname(__FILE__), '..', '..', 'config', 'mongoid.yml'))
