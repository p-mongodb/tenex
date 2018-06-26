require 'evergreen'
require 'github'
require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'travis'

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :views, File.join(File.dirname(__FILE__), '..', 'views')
  set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')

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
    @configs = {
      'mongodb-version' => %w(2.6 3.0 3.2 3.4 3.6 4.0 latest),
      'topology' => %w(standalone replicaset sharded-cluster),
      'auth-and-ssl' => %w(auth-and-ssl noauth-and-nossl),
    }
    @ruby_versions = %w(1.9 2.3 2.4 2.5.0)
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
    restarted = false

    status = @statuses.detect do |status|
      status['context'] == 'continuous-integration/travis-ci/pr'
    end
    if status && status['target_url'] =~ %r,builds/(\d+),
      Travis.access_token = ENV['TRAVIS_TOKEN']
      build = Travis::Build.find($1)
      build.jobs.each do |job|
        if job.failed?
          job.restart
        end
      end
      restarted = true
    end

    status = @statuses.detect do |status|
      status['context'] == 'evergreen'
    end
    if status
      version_id = File.basename(status['target_url'])
      version = Evergreen::Version.new(eg_client, version_id)
      version.restart_failed_builds
      restarted = true
    end

    unless restarted
      return 'Could not find anything to restart'
    end

    redirect return_path || "/pulls/#{pull_id}"
  end

  private def return_path
    URI.parse(request.env['HTTP_REFERER']).path
  end
end
