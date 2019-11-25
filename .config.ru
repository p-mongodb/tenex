$: << File.join(File.dirname(__FILE__), 'lib')

require 'fe/boot'
require 'fe/app'

app = App.new
if ENV['USERNAME'].to_s != '' || ENV['PASSWORD'].to_s != ''
  if ENV['USERNAME'].to_s == '' || ENV['PASSWORD'].to_s == ''
    raise "Both username and password must be set and not empty"
  end
  
  app = Rack::Auth::Basic.new(app) do |username, password|
    Rack::Utils.secure_compare(ENV['USERNAME'], username) &&
    Rack::Utils.secure_compare(ENV['PASSWORD'], password)
  end
end

#app = Rack::ShowExceptions.new(app)
run app
