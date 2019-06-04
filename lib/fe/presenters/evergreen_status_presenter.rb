class EvergreenStatusPresenter
  extend Forwardable

  def initialize(status, pull, eg_client, system)
    @status = status
    @pull = pull
    @eg_client = eg_client
    @system = system
  end

  attr_reader :status
  attr_reader :eg_client, :system
  def_delegators :@status, :[], :context

  def evergreen?
    !!(@status.context =~ %r,evergreen\b,)
  end

  def travis?
    @status.context == 'continuous-integration/travis-ci/pr'
  end

  def build_id
    if @status.context =~ %r,evergreen/,
      File.basename(@status['target_url'])
    else
      # top level build
      nil
    end
  end

  def log_url
    "/repos/#{@pull.repo_full_name}/pulls/#{@pull['number']}/evergreen-log/#{build_id}"
  end

  def mongod_log_url
    project = system.evergreen_project_for_github_repo(@pull.base_owner_name, @pull.base_repo_name)
    "/eg/#{project.id}/versions/#{@pull.evergreen_version_id}/builds/#{build_id}/mongod-log"
  end

  def restart_url
    "/repos/#{@pull.repo_full_name}/pulls/#{@pull['number']}/restart/#{build_id}"
  end

  def evergreen_build
    @evergreen_build ||= Evergreen::Build.new(eg_client, build_id)
  end

  def rspec_json_url
    # top level build has no files hence no rspec json url
    return nil if top_level?

    unless @rspec_json_url_loaded
      task = evergreen_build.tasks.first
      artifact = task.artifacts.detect do |artifact|
        ['rspec.json'].include?(artifact.name)
      end
      @rspec_json_url = artifact&.url
      @rspec_json_url_loaded = true
    end
    @rspec_json_url
  end

  def normalized_status
    Evergreen::Task.normalize_status(status['state'])
  end

  def passed?
    normalized_status == 'passed'
  end

  def failed?
    normalized_status == 'failed'
  end

  def pending?
    normalized_status == 'pending'
  end

  def top_level?
    build_id.nil?
  end

  def attrs
    label, rest = @status.context.split('__')
    map = {}
    return map if rest.nil?
    rest.split('_').each do |bit|
      k, v = bit.split('~')
      map[k] = v
    end
    map
  end

  def prefix
    if attrs['compressor'] == 'zlib'
      'Z'
    elsif attrs['ruby'] == 'ruby-head'
      'H'
    else
      '*'
    end
  end

  def evergreen_version_id
    if status['target_url'] =~ %r,version/([\da-fA-F]+),
      $1
    else
      nil
    end
  end

  def evergreen_version?
    !!evergreen_version_id
  end

  def evergreen_version
    @evergreen_version ||= begin
      evergreen_version_id = self.evergreen_version_id
      if evergreen_version_id.nil?
        raise "No evergreen version"
      end
      Evergreen::Version.new(eg_client, evergreen_version_id)
    end
  end

  def build_count
    if evergreen_version.nil?
      return 0
    end

    evergreen_version.builds.length
  end

  def pending_build_count
    unless evergreen_version?
      return 0
    end

    evergreen_version.builds.select { |build| !build.completed? }.length
  end

  def running_build_count
    unless evergreen_version?
      return 0
    end

    evergreen_version.builds.select { |build| build.running? }.length
  end

  def waiting_build_count
    unless evergreen_version?
      return 0
    end

    evergreen_version.builds.select { |build| build.waiting? }.length
  end

  def failed_build_count
    unless evergreen_version?
      return 0
    end

    evergreen_version.builds.select { |build| build.failed? }.length
  end

  def build_count_str
    counts = []
    if failed_build_count > 0
      counts << [failed_build_count, 'failed']
    end
    if running_build_count > 0
      counts << [running_build_count, 'running']
    end
    if waiting_build_count > 0
      counts << [waiting_build_count, 'waiting']
    end
    unaccounted = pending_build_count - running_build_count - waiting_build_count
    if unaccounted > 0
      counts << [unaccounted, 'unaccounted']
    end

    if counts.any?
      counts[0][0] = "#{counts[0][0]}/#{build_count}"
    else
      counts << [build_count, 'total']
    end

    counts.map do |count, status|
      "#{count} #{status}"
    end.join(', ')
  end

  def eg_unauthorized?
    status['description'] == 'patch must be manually authorized'
  end

  def eg_authorize_url
    "/repos/#{@pull.repo_full_name}/pulls/#{@pull['number']}/authorize/#{evergreen_patch_id}"
  end

  def evergreen_patch_id
    if evergreen_version?
      raise NotImplemented
    else
      File.basename(status['target_url'])
    end
  end

  def time_taken
    evergreen_build.time_taken
  end
end
