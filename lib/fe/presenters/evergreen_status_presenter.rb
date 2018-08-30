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
    "/repos/#{@pull.repo_full_name}/pulls/#{@pull['number']}/evergreen-log/#{build_id}"
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

  def failed?
    status.state == 'failure'
  end

  def top_level?
    build_id.nil?
  end

  def normalized_state
    map = {'failure' => 'failed', 'success' => 'passed', 'pending' => 'pending'}
    map[status['state']].tap do |v|
      if v.nil?
        raise "No map entry for #{status['state']}"
      end
    end
  end
end
