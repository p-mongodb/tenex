class ProjectPresenter
  extend Forwardable

  def initialize(project, eg_client)
    @project = project
    @eg_client = eg_client
  end

  attr_reader :project
  attr_reader :eg_client
  def_delegators :@project, :[], :display_name

  def identifier
    @project['identifier']
  end
end
