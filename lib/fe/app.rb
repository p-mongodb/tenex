autoload :Nokogiri, 'nokogiri'
require 'open-uri'
autoload :Ansi, 'ansi/to/html'
require 'forwardable'
require 'evergreen'
require 'github'
require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'travis'
require 'taw'

Dir[File.join(File.dirname(__FILE__), 'presenters', '*.rb')].each do |path|
  require 'fe/'+path[File.dirname(__FILE__).length+1...path.length].sub(/\.rb$/, '')
end

Travis.access_token = ENV['TRAVIS_TOKEN']

Slim::Engine.set_options pretty: true, sort_attrs: false

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

  get '/' do
    slim :landing
  end

  get '/repos' do
    @repos = Repo.all.sort_by(&:full_name)
    slim :repos
  end

  # repo
  get '/repos/:org/:repo' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    begin
      @pulls = gh_repo(org_name, repo_name).pulls(
        creator: params[:creator],
      )
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
    @pulls.map! { |pull| PullPresenter.new(pull, eg_client, system, @repo) }
    slim :pulls
  end

  get '/repos/:org/:repo/settings' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    slim :settings
  end

  post '/repos/:org/:repo/settings' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    @repo.workflow = params[:workflow] == 'on'
    @repo.evergreen = params[:evergreen] == 'on'
    @repo.travis = params[:travis] == 'on'
    @repo.save!
    redirect "/repos/#{org_name}/#{repo_name}/settings"
  end

  get '/repos/:org/:repo/workflow/:settting' do |org_name, repo_name, setting|
    @repo = system.hit_repo(org_name, repo_name)
    @repo.workflow = setting == 'on'
    @repo.save!
    redirect "/repos/#{@repo.full_name}"
  end

  # pull
  get '/repos/:org/:repo/pulls/:id' do |org_name, repo_name, id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @statuses = @pull.statuses
    @configs = {
      'mongodb-version' => %w(4.0 3.6 3.4 3.2 3.0 2.6 latest),
      'topology' => %w(standalone replica-set sharded-cluster),
      'auth-and-ssl' => %w(noauth-and-nossl auth-and-ssl),
    }
    @ruby_versions = %w(2.5 2.4 2.3 1.9 head jruby-9.2 jruby-9.1)
    slim :pull
  end

  # log
  get '/repos/:org/:repo/pulls/:id/evergreen-log/:build_id' do |org_name, repo_name, pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    log = build.log
    log.gsub!(%r,<i class="fa fa-link line-link" id='line-link-\d+'></i> ,, '')
    lines = log.split("\n")
    lines.each_with_index do |line, index|
      if line =~ %r,Failure/Error:,
        insert_point = [index-3, 0].max
        lines.insert(insert_point, '<a name="first-failure"></a>')
        log = lines.join("\n")
        break
      end
    end
    pull = gh_repo(org_name, repo_name).pull(pull_id)
    title = "#{repo_name}/#{pull_id} by #{pull.creator_name} [#{pull.head_branch_name}]"
    style = %q,
      pre { overflow: initial; }
    ,
    log.sub!(/<\/head>/, "<style>#{style}</style><title>#{title}</title></head>")
    inject = %Q,<p style='margin:1em;font-size:150%'><a href="#{build.log_url}">Log @ Evergreen</a></p>,
    log.sub!(/<body(.*?)>/, "<body\\1>#{inject}")
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
    slim :version
  end

  get '/projects/:project/versions/:version_id/restart-failed' do |project_id, version_id|
    @version = Evergreen::Version.new(eg_client, version_id)
    @version.restart_failed_builds

    redirect return_path || "/projects/#{project_id}/versions/#{version_id}"
  end

  get '/projects/:project/versions/:version_id/bump' do |project_id, version_id|
    @version = Evergreen::Version.new(eg_client, version_id)
    priority = params[:priority].to_i
    if priority == 0
      raise "Bumping to 0?"
    end
    @version.builds.each do |build|
      build.tasks.each do |task|
        unless task.completed?
          task.set_priority(priority)
        end
      end
    end

    redirect return_path || "/projects/#{project_id}/versions/#{version_id}"
  end

  get '/travis/log/:job_id' do |job_id|
    status = Github::Pull::TravisStatus.new(OpenStruct.new(id: job_id))
    log = open(status.raw_log_url).read
    html_log = Ansi::To::Html.new(log).to_html.gsub("\n", '<br>')
  end

  # spawn
  get '/spawn' do
    @distros = distros_with_cache
    @keys = keys_with_cache
    @hosts = eg_client.user_hosts
    @config = SpawnConfig.first || SpawnConfig.new
    @recent_distros = SpawnedHost.recent_distros
    slim :spawn
  end

  post '/spawn' do
    payload = eg_client.spawn_host(distro_name: params[:distro],
      key_name: params[:key])
    spawn_config = SpawnConfig.first || SpawnConfig.new
    spawn_config.last_distro_name = params[:distro]
    spawn_config.last_key_name = params[:key]
    spawn_config.save!
    SpawnedHost.create!(
      distro_name: params[:distro],
      key_name: params[:key],
    )
    redirect "/spawn"
  end

  get '/spawn/:host_id/terminate' do |host_id|
    Evergreen::Host.new(eg_client, host_id).terminate
    redirect "/spawn"
  end

  get '/spawn/terminate-all' do
    eg_client.user_hosts.each do |host|
      host.terminate
    end
    redirect "/spawn"
  end

  private def return_path
    URI.parse(request.env['HTTP_REFERER']).path
  end

  private def distros_with_cache
    cache_state = CacheState.first || CacheState.new
    if cache_state.distros_ok?
      distros = Distro.order(name: 1)
      distros.map do |distro|
        Evergreen::Distro.new(eg_client, distro.name, info: {'name' => distro.name})
      end
    else
      distros = eg_client.distros
      Distro.delete_all
      distros.each do |distro|
        Distro.create!(name: distro.name)
      end
      cache_state.distros_updated_at = Time.now
      cache_state.save!
      distros
    end
  end

  private def keys_with_cache
    cache_state = CacheState.first || CacheState.new
    if cache_state.keys_ok?
      keys = Key.order(name: 1)
      keys.map do |key|
        Evergreen::Key.new(eg_client, key.name, info: {'name' => key.name})
      end
    else
      keys = eg_client.keys
      Key.delete_all
      keys.each do |key|
        Key.create!(name: key.name)
      end
      cache_state.keys_updated_at = Time.now
      cache_state.save!
      keys
    end
  end

  get '/ruby-toolchain-urls' do
    toolchain = Toolchain.new
    toolchain_sha = toolchain.latest_sha
    project = Evergreen::Project.new(eg_client, 'mongo-ruby-driver-toolchain')
    eg_version = project.recent_versions.detect do |version|
      version.revision == toolchain_sha
    end
    @builds = eg_version.builds
    @urls = @builds.map do |build|
      log = build.tasks.first.task_log
      if log =~ %r,Putting mongo-ruby-toolchain/ruby-toolchain.tar.gz into (https://.*),
        $1
      else
        nil
      end
    end
    slim :ruby_toolchain_urls
  end

  get '/projects/:project/versions/:version/results/:build' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    artifact = build.artifact('rspec.json')
    unless artifact
      raise "No rspec.json here"
    end
    url = artifact.url
    contents = open(url).read
    payload = JSON.parse(contents)

    results = payload['examples'].map do |info|
      {
        id: info['id'],
        description: info['full_description'],
        file_path: info['file_path'],
        line_number: info['line_number'],
        time: info['run_time'],
      }.tap do |result|
        if info['status'] == 'failed'
          result[:failure] = {
            message: info['exception']['message'],
            class: info['exception']['class'],
            backtrace: info['exception']['backtrace'],
          }
        end
      end
    end

    @failures = results.select do |result|
      result[:failure]
    end

    @ok = results.select do |result|
      !result[:failure]
    end

    @branch_name = params[:branch]
    slim :results
  end

  get '/projects/:project/versions/:version/tasks/:task/bump' do |project_id, version_id, task_id|
    Task = Evergreen::Task.new(eg_client, task_id).set_priority(99)
    redirect "/projects/#{project_id}/versions/#{version_id}"
  end

  get '/workflow' do
    @repos = Repo.where(workflow: true).sort_by(&:full_name)
    slim :workflow
  end
end
