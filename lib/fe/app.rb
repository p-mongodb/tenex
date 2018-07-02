require 'forwardable'
require 'evergreen'
require 'github'
require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'travis'

Dir[File.join(File.dirname(__FILE__), 'presenters', '*.rb')].each do |path|
  require 'fe/'+path[File.dirname(__FILE__).length+1...path.length].sub(/\.rb$/, '')
end

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'public')

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
    pull = gh_repo.pull(id)
    @pull = PullPresenter.new(pull, eg_client)
    @statuses = @pull.statuses
    @configs = {
      'mongodb-version' => %w(4.0 3.6 3.4 3.2 3.0 2.6 latest),
      'topology' => %w(standalone replicaset sharded-cluster),
      'auth-and-ssl' => %w(noauth-and-nossl auth-and-ssl),
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

  get '/projects' do
    @projects = eg_client.projects.map { |project| ProjectPresenter.new(project, eg_client) }.sort_by { |project| project.display_name.downcase }
    slim :projects
  end

  get '/projects/:project' do |project_id|
    @project = Evergreen::Project.new(eg_client, project_id)
    @patches = @project.recent_patches
    slim :patches
  end

  get '/projects/:project/versions/:version_id' do |project_id, version_id|
    @version = Evergreen::Version.new(eg_client, version_id)
    @builds = @version.builds
    slim :builds
  end

  private def return_path
    URI.parse(request.env['HTTP_REFERER']).path
  end
end
