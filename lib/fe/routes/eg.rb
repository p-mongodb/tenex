autoload :Find, 'find'
autoload :ChildProcess, 'childprocess'
require 'fe/rspec_result'

Routes.included do

  # eg project log
  get "/eg/:project/versions/:version/evergreen-log/:build" do |project_id, version_id, build_id|
    title = 'Evergreen log'
    do_evergreen_log(build_id, title)
  end

  # eg projects list
  get '/eg' do
    @projects = eg_client.projects.map { |project| ProjectPresenter.new(project, eg_client) }.sort_by { |project| project.display_name.downcase }
    slim :projects
  end

  # eg project
  get '/eg/:project' do |project_id|
    @project = Evergreen::Project.new(eg_client, project_id)
    @patches = @project.recent_patches
    @versions = @project.recent_versions
    slim :patches
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

  # eg version bump
  get '/eg/:project/versions/:version_id/bump' do |project_id, version_id|
    version = Evergreen::Version.new(eg_client, version_id)
    do_bump(version, params[:priority].to_i)

    redirect return_path || "/eg/#{project_id}/versions/#{version_id}"
  end

  # eg log
  #get %r,/eg/(?<project>[^/]+)/versions/:version/builds/:build/log, do |project_id, version_id, build_id|
  get '/eg/:project/versions/:version/builds/:build/log' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    title = "EG log"
    do_log(build.task_log, build.task_log_url, title)
  end

  # eg log
  #get %r,/eg/(?<project>[^/]+)/versions/:version/builds/:build/log, do |project_id, version_id, build_id|
  get '/eg/:project/versions/:version/builds/:build/mongod-log' do |project_id, version_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    unless build.tasks.count == 1
      raise "Build has #{build.tasks.count} tasks, need 1"
    end
    task = build.tasks.first
    artifact = task.artifacts.detect do |artifact|
      artifact.name == 'mongodb-logs.tar.gz'
    end
    if artifact.nil?
      raise "Could not find mongodb logs artifact"
    end

    contents = nil
    Dir.mktmpdir do |path|
      Dir.chdir(path) do
        process = ChildProcess.build('tar', 'zxf', '-')
        process.duplex = true
        process.start
        f = open(artifact.url)
        while content = f.read(1048576)
          process.io.stdin.write(content)
        end
        process.io.stdin.close
        process.wait
        unless process.exit_code == 0
          raise "Failed to fetch/untar"
        end

        Find.find('.') do |path|
          if File.basename(path) == 'mongod.log'
            contents = File.read(path)
          end
        end
      end
    end

    if contents
      response.headers['content-type'] = 'text/plain'
      contents
    else
      "No log file found"
    end
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
    @result = RspecResult.new(url, File.open(local_path).read)

    @branch_name = params[:branch]
    slim :results
  end

  get '/eg/:project/versions/:version/tasks/:task/bump' do |project_id, version_id, task_id|
    Task = Evergreen::Task.new(eg_client, task_id).set_priority(99)
    redirect "/eg/#{project_id}/versions/#{version_id}"
  end
end
