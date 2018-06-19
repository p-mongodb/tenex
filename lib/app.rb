require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :views, File.join(File.dirname(__FILE__), '..', 'views')

  def gh_client
    @gh_client ||= Faraday.new('https://api.github.com') do |f|
      f.request :url_encoded
      #f.response :detailed_logger
      f.adapter  Faraday.default_adapter
      f.headers['user-agent'] = 'EvergreenRubyClient'
      f.basic_auth(ENV['GITHUB_USERNAME'], ENV['GITHUB_TOKEN'])
    end
  end

  get '/' do
    resp = gh_client.get('/repos/mongodb/mongo-ruby-driver/pulls')
    payload = JSON.parse(resp.body)
    @pulls = payload
    @pulls.each do |pull|
      sha = pull['head']['sha']
      resp = gh_client.get("/repos/mongodb/mongo-ruby-driver/statuses/#{sha}")
      payload = JSON.parse(resp.body)
      payload.sort_by! { |a| a['context'] }
      pull['success_count'] = payload.inject(0) do |sum, status|
        sum + (status['state'] == 'success' ? 1 : 0)
      end
      pull['failure_count'] = payload.inject(0) do |sum, status|
        sum + (status['state'] == 'failure' ? 1 : 0)
      end
      pull['pending_count'] = payload.inject(0) do |sum, status|
        sum + (%w(success failure).include?(status['state']) ? 0 : 1)
      end
    end
    slim :dashboard
  end

  get '/pulls/:id' do |id|
    resp = gh_client.get("/repos/mongodb/mongo-ruby-driver/pulls/#{id}")
    payload = JSON.parse(resp.body)
    @pull = payload
    sha = @pull['head']['sha']
    resp = gh_client.get("/repos/mongodb/mongo-ruby-driver/statuses/#{sha}?per_page=100")
    payload = JSON.parse(resp.body)
    payload.sort_by! { |a| a['context'] }
    @pull['statuses'] = payload
    slim :pull
  end
end
