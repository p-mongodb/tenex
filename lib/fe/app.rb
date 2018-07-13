require 'forwardable'
require 'evergreen'
require 'github'
require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'travis'
require_relative './models'
require_relative './system'

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
  set :strict_paths, false

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

  def system
    System.new(eg_client, gh_client)
  end

  # repo
  get '/repos/:org/:repo' do |org_name, repo_name|
    system.hit_repo(org_name, repo_name)
    begin
      @pulls = gh_repo(org_name, repo_name).pulls
    rescue Github::Client::ApiError => e
      if e.status == 404
        project = system.evergreen_project_for_github_repo(org_name, repo_name)
        if project
          redirect "/projects/#{project.id}"
          return
        end
      end
      raise
    end
    slim :dashboard
  end

  # pull
  get '/repos/:org/:repo/pulls/:id' do |org_name, repo_name, id|
    system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system)
    @statuses = @pull.statuses
    @configs = {
      'mongodb-version' => %w(4.0 3.6 3.4 3.2 3.0 2.6 latest),
      'topology' => %w(standalone replicaset sharded-cluster),
      'auth-and-ssl' => %w(noauth-and-nossl auth-and-ssl),
    }
    @ruby_versions = %w(1.9 2.3 2.4 2.5.0)
    slim :pull
  end

  # log
  get '/repos/:org/:repo/pulls/:id/evergreen-log/:build_id' do |org_name, repo_name, pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    log = build.log
    inject = %Q,<p style='margin:1em;font-size:150%'><a href="#{build.log_url}">Log @ Evergreen</a></p>,
    log.sub(/<body(.*?)>/, "<body\\1>#{inject}")
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

  get '/repos/:org/:repo/pulls/:id/request-review' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @statuses = @pull.request_review('saghm')

    redirect return_path || "/repos/:org/:repo/pulls/#{pull_id}"
  end

  # eg projects list
  get '/projects' do
    @projects = eg_client.projects.map { |project| ProjectPresenter.new(project, eg_client) }.sort_by { |project| project.display_name.downcase }
    slim :projects
  end

  # eg project
  get '/projects/:project' do |project_id|
    @project = Evergreen::Project.new(eg_client, project_id)
    @patches = @project.recent_patches
    @versions = @project.recent_versions
    slim :patches
  end

  # eg version
  get '/projects/:project/versions/:version_id' do |project_id, version_id|
    @project_id = project_id
    @version = Evergreen::Version.new(eg_client, version_id)
    if @version.pr_info
      @newest_version = system.newest_evergreen_version(@version)
      if @newest_version.id == @version.id
        @newest_version = nil
      end
    end
    @builds = @version.builds
    slim :builds
  end

  get '/projects/:project/versions/:version_id/restart-failed' do |project_id, version_id|
    @version = Evergreen::Version.new(eg_client, version_id)
    @version.restart_failed_builds

    redirect return_path || "/projects/#{project_id}/versions/#{version_id}"
  end

  private def return_path
    URI.parse(request.env['HTTP_REFERER']).path
  end
end
