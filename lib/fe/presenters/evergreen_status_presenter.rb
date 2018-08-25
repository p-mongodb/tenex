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

  def junit_xml_url
    unless @junit_xml_url_loaded
      task = evergreen_build.tasks.first
      rspec_xml_artifact = task.artifacts.detect do |artifact|
        [' rspec.xml', 'rspec.xml'].include?(artifact.name)
      end
      @junit_xml_url = rspec_xml_artifact&.url
      @junit_xml_url_loaded = true
    end
    @junit_xml_url
  end

  def failed?
    status.state == 'failure'
  end
end
