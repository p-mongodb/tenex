require 'dotenv'
require 'byebug'
#require 'bundler/setup'

Dotenv.load(File.join(File.dirname(__FILE__), '../../config/env'))

require 'oj'
Oj.default_options = {mode: :compat}

autoload :Github, 'github'
autoload :Evergreen, 'evergreen'
