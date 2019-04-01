class EvergreenTaskPresenter
  extend Forwardable

  def initialize(task, pull, eg_client, system)
    @task = task
    @pull = pull
    @eg_client = eg_client
    @system = system
  end

  attr_reader :task
  attr_reader :eg_client, :system
  def_delegators :@task, :normalized_status, :id, :ui_url, :build_id,
    :task_log_url, :time_taken

  def restart_url
    "/repos/#{@pull.repo_full_name}/pulls/#{@pull['number']}/restart/#{build_id}"
  end

  def results_url
    "/eg/#{URI.escape(@pull.evergreen_project_id)}/versions/#{@pull.evergreen_version_id}/results/#{build_id}?branch=#{@pull.head_branch_name}"
  end
end
