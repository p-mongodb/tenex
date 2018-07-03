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

Travis.access_token = ENV['TRAVIS_TOKEN']

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

  def gh_repo(org_name, repo_name)
    gh_client.repo(org_name, repo_name)
  end

  def eg_client
    @eg_client ||= Evergreen::Client.new(
        username: ENV['EVERGREEN_AUTH_USERNAME'],
        api_key: ENV['EVERGREEN_API_KEY'],
      )
  end

  get '/repos/:org/:repo' do |org_name, repo_name|
    @pulls = gh_repo(org_name, repo_name).pulls
    slim :dashboard
  end

  get '/repos/:org/:repo/pulls/:id' do |org_name, repo_name, id|
    pull = gh_repo(org_name, repo_name).pull(id)
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

  get '/repos/:org/:repo/pulls/:id/evergreen-log/:build_id' do |org_name, repo_name, pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    build.log

  end

  get '/repos/:org/:repo/pulls/:id/restart/:build_id' do |org_name, repo_name, pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    build.restart
    redirect "/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/restart-failed' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @statuses = @pull.statuses
    restarted = false

    @pull.travis_statuses.each do |status|
      if status.failed?
        status.restart
      end
      restarted = true
    end

    status = @pull.top_evergreen_status
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
