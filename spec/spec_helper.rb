$: << File.join(File.dirname(__FILE__), '../../lib')

autoload :Byebug, 'byebug'

ENV['MONGOID_ENV'] = 'test'

RSpec.configure do |config|
  config.expect_with(:rspec) do |c|
    c.syntax = :should
  end
end
