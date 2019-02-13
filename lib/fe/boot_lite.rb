require 'dotenv'
require 'byebug'

Dotenv.load(File.join(File.dirname(__FILE__), '../../.env'))

autoload :Github, 'github'
autoload :Evergreen, 'evergreen'
