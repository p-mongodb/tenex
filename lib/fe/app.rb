autoload :JIRA, 'jira-ruby'
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
autoload :Jirra, 'jirra/client'

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
    @ruby_versions = %w(2.6 2.5 2.4 2.3 2.2 1.9 head jruby-9.2 jruby-9.1)
    @table_keys = %w(mongodb-version topology auth-and-ssl ruby)
    @category_values = {}
    @table = {}
    @untaken_statuses = []
    @pull.statuses.each do |status|
      if repo_name == 'mongo-ruby-driver' && status.status.context =~ %r,evergreen/,
        id = status.status.context.split('/')[1]
        label, rest = id.split('__')
        meta = {}
        rest.split('_').each do |pair|
          key, value = pair.split('~')
          case key
          when 'ruby'
            meta[key] = value.sub(/^ruby-/, '')
          else
            meta[key] = value
          end
        end
        if label =~ /enterprise-auth-tests-ubuntu/
          meta['mongodb-version'] = 'EA'
          meta['topology'] = 'ubuntu'
        elsif label =~ /enterprise-auth-tests-rhel/
          meta['mongodb-version'] = 'EA'
          meta['topology'] = 'rhel'
        else
          meta['auth-and-ssl'] ||= 'noauth-and-nossl'
        end
        @table_keys.each do |key|
          value = meta[key]
          if value.nil?
            raise "Missing #{key} in #{meta}"
          end
          @category_values[key] ||= []
          (@category_values[key] << value).uniq!
        end
        meta_for_label = meta.dup
        map = @table_keys.inject(@table) do |map, key|
          (map[meta[key]] ||= {}).tap do
            meta_for_label.delete(key)
          end
        end
        short_label = ''
        if meta_for_label.delete('as')
          short_label << 'AS'
        end
        if meta_for_label.delete('lint')
          short_label << 'L'
        end
        if meta_for_label.delete('retry-writes')
          short_label << 'RW'
        end
        if compressor = meta_for_label.delete('compressor')
          short_label << compressor[0].upcase
        end
        if meta_for_label.empty?
          if short_label.empty?
            short_label = '*'
          end
        else
          extra = meta_for_label.map { |k, v| "#{k}=#{v}" }.join(',')
          if short_label.empty?
            short_label = extra
          else
            short_label += '; ' + extra
          end
        end
        if map[short_label]
          raise "overwrite for #{short_label} #{meta.inspect}"
        end
        map[short_label] = status
      else
        @untaken_statuses << status
      end
    end
    @branch_name = @pull.head_branch_name
    if repo_name == 'mongo-ruby-driver' && @category_values
      @category_values['ruby']&.sort! do |a, b|
        if a =~ /^[0-9]/ && b =~ /^[0-9]/ || a =~ /^j/ && b =~ /^j/
          b <=> a
        else
          a <=> b
        end
      end
      @category_values['mongodb-version']&.sort! do |a, b|
        if a =~ /^[0-9]/ && b =~ /^[0-9]/
          b <=> a
        else
          a <=> b
        end
      end
      @category_values['mongodb-version']&.delete('EA')
      @category_values['mongodb-version']&.push('EA')
      if @category_values['topology']
        @category_values['topology'] = %w(standalone replica-set sharded-cluster rhel ubuntu)
      end
    end
    if @category_values.empty?
      @category_values = nil
    end
    slim :pull
  end

  # pull perf
  get '/repos/:org/:repo/pulls/:id/perf' do |org_name, repo_name, id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @statuses = @pull.statuses.sort_by do |status|
      if status.build_id.nil?
        # top level build
        -1000000
      else
        -status.time_taken
      end
    end
    @branch_name = @pull.head_branch_name
    slim :pull_perf
  end

  # eg project log
  get "/projects/:project/versions/:version/evergreen-log/:build" do |project_id, version_id, build_id|
    title = 'Evergreen log'
    do_evergreen_log(build_id, title)
  end

  # pr log
  get '/repos/:org/:repo/pulls/:id/evergreen-log/:build_id' do |org_name, repo_name, pull_id, build_id|
    pull = gh_repo(org_name, repo_name).pull(pull_id)
    title = "#{repo_name}/#{pull_id} by #{pull.creator_name} [#{pull.head_branch_name}]"
    do_evergreen_log(build_id, title)
  end

  private def do_evergreen_log(build_id, title)
    build = Evergreen::Build.new(eg_client, build_id)
    do_log(build.task_log, build.task_log_url, title)
  end

  private def do_log(log, log_url, title)
    log = log.gsub(%r,<i class="fa fa-link line-link" id='line-link-\d+'></i> ,, '')
    lines = log.split("\n")
    lines.each_with_index do |line, index|
      if line =~ %r,Failure/Error:,
        insert_point = [index-3, 0].max
        lines.insert(insert_point, '<a name="first-failure"></a>')
        log = lines.join("\n")
        break
      end
    end
    style = %q,
      pre { overflow: initial; }
    ,
    log.sub!(/<\/head>/, "<style>#{style}</style><title>#{title}</title></head>")
    inject = %Q,<p style='margin:1em;font-size:150%'><a href="#{log_url}">Log @ Evergreen</a></p>,
    log.sub!(/<body(.*?)>/, "<body\\1>#{inject}")
    log
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

    jira_ticket = @pull.jira_ticket!
    transitions = jirra_client.get_json("issue/#{jira_ticket}/transitions")
    byebug
    transition = transitions['transitions'].detect do |tr|
      tr['name'] == 'In Code Review'
    end
    if transition
      transition_id = transition['id']

      payload = {
        fields: {
          assignee: {
            name: 'oleg.pudeyev',
          },
        },
        transition: {
          id: transition_id,
        },
      }
      jirra_client.post_json("issue/#{jira_ticket}/transitions", payload)
    end

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/rebase' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.rebase(@pull)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/reword' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.reword(@pull)
    subject, message = rc.commitish_message(@pull.head_branch_name)
    @pull.update(title: subject, body: message)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/retitle' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    subject, message = rc.commitish_message(@pull.head_sha)
    @pull.update(title: subject, body: message)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/submit-patch' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.add_remote(@pull.head_owner_name, @pull.head_repo_name)
    diff = rc.diff_to_master(@pull.head_sha)
    repo = system.hit_repo(org_name, repo_name)
    rv = eg_client.create_patch(
      project_id: repo.evergreen_project_id,
      diff_text: diff,
      base_sha: rc.master_sha,
      description: 'foo',
      variant_ids: ['all'],
      task_ids: ['all'],
      finalize: true,
    )

    patch_id = rv['patch']['Id']

    # TODO record patch internally and link it to the PR

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  # pull bump
  get '/repos/:org/:repo/pulls/:id/bump' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    version = Evergreen::Version.new(eg_client, @pull.evergreen_version_id)
    do_bump(version, params[:priority].to_i)
    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  # eg authorize pr
  get '/repos/:org/:repo/pulls/:id/authorize/:patch' do |org_name, repo_name, pull_id, patch_id|
    patch = Evergreen::Patch.new(eg_client, patch_id)
    patch.authorize!
    redirect return_path || "/repos/#{org_name}/#{repo_name}/pulls/#{pull_id}"
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

  # eg version bump
  get '/projects/:project/versions/:version_id/bump' do |project_id, version_id|
    version = Evergreen::Version.new(eg_client, version_id)
    do_bump(version, params[:priority].to_i)

    redirect return_path || "/projects/#{project_id}/versions/#{version_id}"
  end

  private def do_bump(version, priority)
    if priority == 0
      raise "Bumping to 0?"
    end
    version.builds.each do |build|
      build.tasks.each do |task|
        unless task.completed?
          task.set_priority(priority)
        end
      end
    end
  end

  # eg log
  #get %r,/projects/(?<project>[^/]+)/versions/:version/builds/:build/log, do |project_id, version_id, build_id|
  get '/projects/:project/versions/:version/builds/:build/log' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    title = "EG log"
    do_log(build.task_log, build.task_log_url, title)
  end

  # eg task log
  get '/projects/:project/versions/:version/builds/:build/tasks/:task/log' do |project_id, version_id, build_id, task_id|
    task = Evergreen::Task.new(eg_client, task_id)
    title = "EG task log"
    do_log(task.task_log, task.task_log_url, title)
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
    @build = Evergreen::Build.new(eg_client, build_id)
    artifact = @build.artifact('rspec.json')
    unless artifact
      redirect "/projects/#{project_id}/versions/#{version_id}/evergreen-log/#{build_id}"
      return
    end
    @raw_artifact_url = url = artifact.url
    contents = open(url).read
    payload = JSON.parse(contents)
    @summary = {}
    payload['summary'].each do |k, v|
      @summary[k.to_sym] = v
    end

    results = payload['examples'].map do |info|
      {
        id: info['id'],
        description: info['full_description'],
        file_path: info['file_path'],
        line_number: info['line_number'],
        time: info['run_time'],
        sdam_log_entries: info['sdam_log_entries'],
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

    @messages = payload['messages']

    @failures = results.select do |result|
      result[:failure]
    end

    @ok = results.select do |result|
      !result[:failure]
    end

    failed_files = {}
    @failures.each do |failure|
      failed_files[failure[:file_path]] ||= 0
      failed_files[failure[:file_path]] += 1
    end
    @failed_files = []
    failed_files.keys.each do |key|
      @failed_files << {
        file_path: key, failure_count: failed_files[key],
      }
    end

    results_by_time = results.sort_by do |result|
      -(result[:time] || 0)
    end
    @slowest_results = results_by_time[0..19]
    @slowest_total_time = @slowest_results.inject(0) do |sum, result|
      sum + result[:time]
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

  get '/jira/:project/fixed/:version' do |project_name, version|
    project_name = project_name.upcase
    @issues = JIRA::Resource::Issue.jql(jira_client,
      "project=#{project_name} and fixversion=#{version} order by type, priority desc, key",
      max_results: 500)
    slim :fixed_issues
  end

  get '/jira/:project/epics' do |project_name|
    project_name = project_name.upcase
    @issues = JIRA::Resource::Issue.jql(jira_client,
      "project=#{project_name} and type=epic order by resolution desc, updated desc",
      max_results: 50)
    slim :epics
  end

  get '/jira/editmeta' do
    @heading = 'Edit Meta'
    @payload = jirra_client.get_json('issue/RUBY-1690/editmeta')
    slim :editmeta
  end

  get '/jira/transitions' do
    @heading = 'Transitions'
    @payload = jirra_client.get_json('issue/RUBY-1690/transitions')
    slim :editmeta
  end

  get '/jira/statuses' do
    @heading = 'Statuses'
    @payload = jirra_client.get_json('project/RUBY/statuses')
    slim :editmeta
  end

  private def jira_client
    @jira_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
        :context_path => '',
        :auth_type    => :basic
      }

      JIRA::Client.new(options)
    end
  end

  private def jirra_client
    @jira_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
      }

      ::Jirra::Client.new(options)
    end
  end
end
