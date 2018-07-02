require 'forwardable'
require 'evergreen'
require 'github'
require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'travis'

class EvergreenStatusPresenter
  extend Forwardable

  def initialize(status, pull, eg_client)
    @status = status
    @pull = pull
    @eg_client = eg_client
  end

  attr_reader :status
  attr_reader :eg_client
  def_delegators :@status, :[], :context

  def build_id
    if @status.context =~ %r,evergreen/,
      File.basename(@status['target_url'])
    else
      # top level build
      nil
    end
  end

  def log_url
    "/pulls/#{@pull['number']}/evergreen-log/#{build_id}"
  end

  def restart_url
    "/pulls/#{@pull['number']}/restart/#{build_id}"
  end

  def evergreen_build
    Evergreen::Build.new(eg_client, build_id)
  end
end

class PullPresenter
  extend Forwardable

  def initialize(pull, eg_client)
    @pull = pull
    @eg_client = eg_client
  end

  attr_reader :pull
  attr_reader :eg_client
  def_delegators :@pull, :[]

  def statuses
    @statuses ||= @pull.statuses.map do |status|
      EvergreenStatusPresenter.new(status, @pull, eg_client)
    end
  end

  def take_status(label)
    status = statuses.detect { |s| s['context'] == label }
    if status
      @taken_statuses ||= {}
      @taken_statuses[status.context] = true
    end
    status
  end

  def untaken_statuses
    statuses.reject do |status|
      @taken_statuses && @taken_statuses[status['context']]
    end
  end

  def top_evergreen_status
    status = @pull.top_evergreen_status
    if status
      status = EvergreenStatusPresenter.new(status, @pull, eg_client)
    end
    status
  end

  def evergreen_version
    @evergreen_version ||= Evergreen::Version.new(eg_client, @pull.evergreen_version_id)
  end
end

class ProjectPresenter
  extend Forwardable

  def initialize(project, eg_client)
    @project = project
    @eg_client = eg_client
  end

  attr_reader :project
  attr_reader :eg_client
  def_delegators :@project, :[], :display_name

  def identifier
    @project['identifier']
  end
end

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

  private def return_path
    URI.parse(request.env['HTTP_REFERER']).path
  end
end
