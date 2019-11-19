autoload :Find, 'find'
autoload :ChildProcess, 'childprocess'
require 'fe/rspec_result'

Routes.included do

  # eg project log
  get "/eg/:project/versions/:version/evergreen-log/:build" do |project_id, version_id, build_id|
    title = 'Evergreen log'
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
      if @newest_version.id == @version.id
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
    do_log(build.task_log, build.task_log_url, title)
  end

  get '/eg/:project/versions/:version/builds/:build/log/all' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    title = "All EG log"
    do_log(build.all_log, build.all_log_url, title)
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

  get '/eg/:project/versions/:version/builds/:build/artifact-log/*rel_path' do |project_id, version_id, build_id, rel_path|
    build = Evergreen::Build.new(eg_client, build_id)
    artifact = build.detect_artifact!('mongodb-logs.tar.gz')
    contents = artifact.extract_tarball_path(rel_path)

    if contents
      response.headers['content-type'] = 'text/plain'
      contents
    else
      "No log file found"
    end
  end

  get '/eg/:project/versions/:version/builds/:build/artifact-logs' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    artifact = build.detect_artifact!('mongodb-logs.tar.gz')
    @files = artifact.tarball_file_infos

    @project_id = project_id
    @version_id = version_id
    @build_id = build_id
    slim :artifact_logs
  end

  # eg task log
  get '/eg/:project/versions/:version/builds/:build/tasks/:task/log' do |project_id, version_id, build_id, task_id|
    task = Evergreen::Task.new(eg_client, task_id)
    title = "EG task log"
    do_log(task.task_log, task.task_log_url, title)
  end

  get '/eg/:project/versions/:version/results/:build' do |project_id, version_id, build_id|
    @build = Evergreen::Build.new(eg_client, build_id)
    artifact = @build.artifact('rspec.json')
    unless artifact
      redirect "/eg/#{project_id}/versions/#{version_id}/evergreen-log/#{build_id}"
      return
    end
    @raw_artifact_url = url = artifact.url
    local_path = ArtifactCache.instance.fetch_artifact(url)
    content = File.read(local_path)
    if content.empty?
      # Happens sometimes
      redirect "/eg/#{project_id}/versions/#{version_id}/evergreen-log/#{build_id}"
      return
    end
    @result = RspecResult.new(url, content)

    @branch_name = params[:branch]
    slim :results
  end

  get '/eg/:project/versions/:version/tasks/:task/bump' do |project_id, version_id, task_id|
    Task = Evergreen::Task.new(eg_client, task_id).set_priority(99)
    redirect "/eg/#{project_id}/versions/#{version_id}"
  end
end
