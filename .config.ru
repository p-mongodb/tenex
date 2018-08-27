$: << File.join(File.dirname(__FILE__), 'lib')

require 'fe/boot'
require 'fe/app'

run App
