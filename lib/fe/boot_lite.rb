require 'dotenv'
require 'byebug'

Dotenv.load(File.join(File.dirname(__FILE__), '../../.env'))

require 'oj'
Oj.default_options = {mode: :compat}

autoload :Github, 'github'
autoload :Evergreen, 'evergreen'
