module Routes
module Eg
  extend ActiveSupport::Concern

  included do

    # eg project log
    get "/projects/:project/versions/:version/evergreen-log/:build" do |project_id, version_id, build_id|
      title = 'Evergreen log'
      do_evergreen_log(build_id, title)
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

    get '/projects/:project/versions/:version_id/restart-all' do |project_id, version_id|
      @version = Evergreen::Version.new(eg_client, version_id)
      @version.restart_all_builds

      redirect return_path || "/projects/#{project_id}/versions/#{version_id}"
    end

    # eg version bump
    get '/projects/:project/versions/:version_id/bump' do |project_id, version_id|
      version = Evergreen::Version.new(eg_client, version_id)
      do_bump(version, params[:priority].to_i)

      redirect return_path || "/projects/#{project_id}/versions/#{version_id}"
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
  end
end
end
