require 'dotenv'
require 'byebug'

Dotenv.load(File.join(File.dirname(__FILE__), '../../config/env'))

require 'oj'
Oj.default_options = {mode: :compat}

autoload :Github, 'github'
autoload :Evergreen, 'evergreen'
