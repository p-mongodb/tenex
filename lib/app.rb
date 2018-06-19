require 'evergreen'
require 'github'
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
    @gh_client ||= Github::Client.new(
        username: ENV['GITHUB_USERNAME'],
        auth_token: ENV['GITHUB_TOKEN'],
      )
  end

  def gh_repo
    gh_client.repo('mongodb', 'mongo-ruby-driver')
  end

  def eg_client
    @eg_client ||= Evergreen::Client.new(
        username: ENV['EVERGREEN_AUTH_USERNAME'],
        api_key: ENV['EVERGREEN_API_KEY'],
      )
  end

  get '/' do
    @pulls = gh_repo.pulls
    @pulls.each do |pull|
      sha = pull.head_sha
      statuses = pull.statuses
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
    @pull = gh_repo.pull(id)
    @statuses = @pull.statuses
    @statuses.each do |status|
      if status['context'] =~ /^evergreen\// && status['target_url']
        build_id = File.basename(status['target_url'])
        status['log_url'] = "/pulls/#{id}/evergreen-log/#{build_id}"
        status['restart_url'] = "/pulls/#{id}/restart/#{build_id}"
      end
    end
    slim :pull
  end

  get '/pulls/:id/evergreen-log/:build_id' do |pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    build.log

  end

  get '/pulls/:id/restart/:build_id' do |pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    build.restart
    redirect "/pulls/#{pull_id}"
  end

  get '/pulls/:id/restart-failed' do |pull_id|
    @pull = gh_repo.pull(pull_id)
    @statuses = @pull.statuses
    status = @statuses.detect do |status|
      status['context'] == 'evergreen'
    end
    if status.nil?
      return 'Could not find'
    end
    version_id = File.basename(status['target_url'])
    version = Evergreen::Version.new(eg_client, version_id)
    version.restart_failed_builds
    redirect "/pulls/#{pull_id}"
  end
end
