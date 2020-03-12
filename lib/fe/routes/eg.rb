autoload :Find, 'find'
autoload :ChildProcess, 'childprocess'
require 'fe/rspec_result'

Routes.included do

  get '/eg/update-binary' do
    system.fetch_evergreen_binary
    redirect return_path || '/'
  end

  get '/eg/distros' do
    hosts = eg_client.hosts
    @distros = hosts.map(&:distro).sort.uniq(&:id)
    slim :distros
  end

  # eg project log
  get "/eg/:project/versions/:version/evergreen-log/:build" do |project_id, version_id, build_id|
    @project_id = project_id
    @version_id = version_id
    version = eg_client.version_by_id(version_id)
    title = "Evergreen log - #{version.message.sub(%r, \(https://github.com/.*?\),, '')}"
    if version.message =~ %r,https://github.com/([^/]+)/([^/]+)/pull/(\d+),
      @owner_name = $1
      @repo_name = $2
      @pull_id = $3
    end
    do_evergreen_log(build_id, title)
  end

  get "/eg/:project/versions/:version/evergreen-log/:build/all" do |project_id, version_id, build_id|
    title = 'All Evergreen log'
    do_evergreen_log(build_id, title, :all)
  end

  # eg projects list
  get '/eg' do
    projects = eg_client.projects
    if params[:filter] == 'ruby'
      projects.select! do |project|
        project.admin_usernames.include?(ENV['EVERGREEN_AUTH_USERNAME']) &&
          project.id =~ /ruby|mongoid/i
      end
    end
    @projects = projects.map { |project| ProjectPresenter.new(project, eg_client) }.sort_by { |project| project.display_name.downcase }
    slim :eg_projects
  end

  # eg project
  get '/eg/:project' do |project_id|
    @project = Evergreen::Project.new(eg_client, project_id)
    @patches = @project.recent_patches
    @versions = @project.recent_versions
    slim :patches
  end

  # eg project config vars
  get '/eg/:project/config' do |project_id|
    @project = Evergreen::Project.new(eg_client, project_id)
    slim :eg_project_config
  end

  # eg project config vars
  get '/eg/:project/config.env' do |project_id|
    @project = Evergreen::Project.new(eg_client, project_id)
    out = ''
    @project.vars.each do |k, v|
      if v =~ /\s/
        out << %Q`#{k}="#{v}"\n`
      else
        out << %Q`#{k}=#{v}\n`
      end
    end
    response.header['content-type'] = 'text/plain'
    out
  end

  get '/eg/:project/patches/:patch_id' do |project_id, patch_id|
    patch = eg_client.patch_by_id(patch_id)
    version = patch.version
    redirect "/eg/#{project_id}/versions/#{version.id}"
  end

  # eg version
  get '/eg/:project/versions/:version_id' do |project_id, version_id|
    @project_id = project_id
    @version = Evergreen::Version.new(eg_client, version_id)
    if @version.pr_info
      @newest_version = system.newest_evergreen_version(@version)
      if @newest_version && @newest_version.id == @version.id
        @newest_version = nil
      end
    end
    @builds = @version.builds
    slim :version
  end

  get '/eg/:project/versions/:version_id/restart-failed' do |project_id, version_id|
    @version = Evergreen::Version.new(eg_client, version_id)
    @version.restart_failed_builds

    redirect return_path || "/eg/#{project_id}/versions/#{version_id}"
  end

  get '/eg/:project/versions/:version_id/restart-all' do |project_id, version_id|
    @version = Evergreen::Version.new(eg_client, version_id)
    @version.restart_all_builds

    redirect return_path || "/eg/#{project_id}/versions/#{version_id}"
  end

  get '/eg/:project/versions/:version_id/tasks/:task_id/restart' do |project_id, version_id, task_id|
    @task = Evergreen::Task.new(eg_client, task_id)
    @task.restart

    redirect return_path || "/eg/#{project_id}/versions/#{version_id}"
  end

  # eg version bump
  get '/eg/:project/versions/:version_id/bump' do |project_id, version_id|
    version = Evergreen::Version.new(eg_client, version_id)
    do_bump(version, params[:priority].to_i)

    redirect return_path || "/eg/#{project_id}/versions/#{version_id}"
  end

  get '/eg/:project/versions/:version_id/abort' do |project_id, version_id|
    version = Evergreen::Version.new(eg_client, version_id)
    version.abort

    redirect return_path || "/eg/#{project_id}/versions/#{version_id}"
  end

  # eg log
  #get %r,/eg/(?<project>[^/]+)/versions/:version/builds/:build/log, do |project_id, version_id, build_id|
  get '/eg/:project/versions/:version/builds/:build/log' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    title = "EG log"
    do_evergreen_log(build.id, title, :task)
  end

  get '/eg/:project/versions/:version/builds/:build/log/all' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    title = "All EG log"
    do_evergreen_log(build.id, title, :all)
  end

  # eg log
  #get %r,/eg/(?<project>[^/]+)/versions/:version/builds/:build/log, do |project_id, version_id, build_id|
  get '/eg/:project/versions/:version/builds/:build/mongod-log' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    artifact = build.detect_artifact!('mongodb-logs.tar.gz')
    contents = artifact.extract_tarball_file('mongod.log')

    if contents
      response.headers['content-type'] = 'text/plain'
      contents
    else
      "No log file found"
    end
  end

  # artifact log
  get '/eg/:project/versions/:version/builds/:build/artifact-log/*rel_path' do |project_id, version_id, build_id, rel_path|
    @project_id = project_id
    @version_id = version_id
    build = Evergreen::Build.new(eg_client, build_id)
    @artifact = build.detect_artifact!('mongodb-logs.tar.gz')

    contents = @artifact.tarball_entry(rel_path) do |entry|
      entry.read
    end

    if contents
      if File.basename(rel_path) =~ /^mongo[ds]\b.*\.log\b/
        colorize_server_log(contents)
      else
        response.headers['content-type'] = 'text/plain'
        contents
      end
    else
      "No log file found"
    end
  end

  get '/eg/:project/versions/:version/builds/:build/artifact-logs' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    @artifact = build.detect_artifact!('mongodb-logs.tar.gz')
    @files = @artifact.tarball_file_infos

    @project_id = project_id
    @version_id = version_id
    @build_id = build_id
    slim :artifact_logs
  end

  # eg task log
  get '/eg/:project/versions/:version/builds/:build/tasks/:task/log' do |project_id, version_id, build_id, task_id|
    task = Evergreen::Task.new(eg_client, task_id)
    title = "EG task log"
    do_simple_evergreen_log(task.task_log, task.task_log_url, title)
  end

  # eg build results
  get '/eg/:project/versions/:version/results/:build' do |project_id, version_id, build_id|
    @build = Evergreen::Build.new(eg_client, build_id)
    artifact = @build.artifact('rspec.json')
    unless artifact
      return results_fallback(project_id, version_id, @build)
    end
    @raw_artifact_url = url = artifact.url
    local_path = ArtifactCache.instance.fetch_artifact(url)
    content = File.read(local_path)
    if content.empty?
      # Happens sometimes
      return results_fallback(project_id, version_id, @build)
    end
    @result = RspecResult.new(url, content)

    cached_build, log_lines, log_url = EvergreenCache.build_log(@build, :task)
    set_local_test_command(log_lines, result: @result)

    @branch_name = params[:branch]
    slim :results
  end

  def results_fallback(project_id, version_id, build)
    logs = build.detect_artifact('mongodb-logs.tar.gz')
    if logs
      logs.tarball_each do |entry|
        contents = entry.read
        next unless contents
        if entry.full_name =~ /\.log$/
          contents.force_encoding('utf-8')
        end
        if start = (contents =~ /(Got signal: (\d+)(.|\n)*----- BEGIN BACKTRACE -----(.|\n)*-----  END BACKTRACE  -----)/)
          @log_name = entry.full_name
          @log_url = "/eg/#{project_id}/versions/#{version_id}/builds/#{build.id}/artifact-log/#{@log_name}"
          @fragment = contents[start-5000...contents.length]
          @fragment = @fragment[@fragment.index("\n")...@fragment.length]
          return slim :server_crash
        end
      end
    end

    redirect "/eg/#{project_id}/versions/#{version_id}/evergreen-log/#{build.id}"
  end

  get '/eg/:project/versions/:version/tasks/:task/bump' do |project_id, version_id, task_id|
    Task = Evergreen::Task.new(eg_client, task_id).set_priority(99)
    redirect "/eg/#{project_id}/versions/#{version_id}"
  end

  get '/eg/:project/versions/:version_id/toolchain-urls' do |project_id, version_id|
    version = Evergreen::Version.new(eg_client, version_id)
    @urls = {}
    version.builds.each do |build|
      @urls[build.build_variant] = case build.status
      when 'success'
        log = build.tasks.first.task_log.dup.force_encoding('utf-8')
        log.sub!(/\A(.|\n)+?Running command.*s3\.put/, '')
        if log =~ %r,Putting (mongo-ruby-toolchain/ruby-toolchain.tar.gz|src/python.tar.gz) into (https://s3.amazonaws.com/[^<]+),
          $2
        else
          'missing url'
        end
      else
        'n/a'
      end
    end
    k, v = @urls.first
    path = URI.parse(v).path.sub(%r,^//,, '/')
    _, mciuploads, @toolchain_project_name, distro, version_id, basename = path.split('/')
    @toolchain_upper = version_id
    @toolchain_lower = basename.sub(/.+#{version_id}_/, '').sub(/\.tar\.gz$/, '')
    @shell_template = v.sub(k, "`host_arch`").sub(k, "`host_arch |tr - _`").
      gsub(@toolchain_upper, '$toolchain_upper').sub(@toolchain_lower, '$toolchain_lower')
    @ruby_template = v.sub(k, '#{distro}').sub(k, %q`#{distro.gsub('-', '_')}`).
      gsub(@toolchain_upper, '#{toolchain_upper}').sub(@toolchain_lower, '#{toolchain_lower}')
    slim :version_toolchain_urls
  end

  private

  SEVERITIES = %w(E W I D).freeze

  def colorize_server_log(contents)
    lines = contents.split("\n")
    num = 0
    @log_lines = lines.map do |line|
      num += 1
      severity = line.split(/\s+/, 3)[1]
      unless severity && SEVERITIES.include?(severity)
        severity = 'I'
      end
      {
        num: num,
        text: line,
        severity: severity,
      }
    end
    slim :eg_server_log
  end
end
