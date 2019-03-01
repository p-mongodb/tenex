require 'fe/artifact_cache'
require 'fe/mappings'

class PullPresenter
  extend Forwardable

  def initialize(pull, eg_client, system, repo)
    @pull = pull
    @eg_client = eg_client
    @system = system
    @repo = repo
  end

  attr_reader :pull
  attr_reader :eg_client, :system
  def_delegators :@pull, :[], :repo_full_name, :travis_statuses,
    :evergreen_version_id, :head_branch_name,
    :approved?, :review_requested?

  def statuses
    @statuses ||= @pull.statuses.map do |status|
      status = EvergreenStatusPresenter.new(status, @pull, eg_client)
      if status.travis? && !@repo.travis?
        nil
      else
        status
      end
    end.compact
  end

  def take_status(label)
    status = statuses.detect { |s| s['context'] == label }
    if status
      @taken_statuses ||= {}
      @taken_statuses[status.context] = true
    end
    status
  end

  def take_statuses(attrs)
    untaken_statuses.select do |status|
      (status.attrs.slice(*attrs.keys) == attrs).tap do |v|
        if v
          @taken_statuses ||= {}
          @taken_statuses[status.context] = true
        end
      end
    end
  end

  def untaken_statuses
    statuses.reject do |status|
      @taken_statuses && @taken_statuses[status['context']]
    end
  end

  def top_evergreen_status
    status = @pull.top_evergreen_status
    if status
      status = EvergreenStatusPresenter.new(status, @pull, eg_client)
    end
    status
  end

  def evergreen_version
    @evergreen_version ||= Evergreen::Version.new(eg_client, @pull.evergreen_version_id)
  end

  def evergreen_project_id?
    !!system.evergreen_project_for_github_repo
  end

  def evergreen_project_id
    system.evergreen_project_for_github_repo!(pull.repo_full_name.split('/').first, pull.repo_full_name.split('/')[1]).id
  end

  def have_rspec_json?
    return @have_rspec_json unless @have_rspec_json.nil?
    @have_rspec_json = !!statuses.detect do |status|
      status.failed? && status.rspec_json_url
    end
  end

  private def non_top_level_statuses
    statuses = self.statuses
    non_tl = statuses.any? do |status|
      status.evergreen? && !status.top_level?
    end
    if non_tl
      statuses = statuses.reject do |status|
        status.evergreen? && status.top_level?
      end
    end
    statuses
  end

  def success_count
    @success_count ||= non_top_level_statuses.inject(0) do |sum, status|
      sum + (status['state'] == 'success' ? 1 : 0)
    end
  end

  def failure_count
    @failure_count ||= non_top_level_statuses.inject(0) do |sum, status|
      sum + (status['state'] == 'failure' ? 1 : 0)
    end
  end

  def pending_count
    @pending_count ||= non_top_level_statuses.inject(0) do |sum, status|
      sum + (%w(success failure).include?(status['state']) ? 0 : 1)
    end
  end

  def green?
    #success_count > 0 && failure_count == 0 && pending_count == 0
    top_evergreen_status&.passed?
  end

  def jira_project
    ::Mappings.repo_full_name_to_jira_project(repo_full_name)
  end

  def jira_ticket_number
    if @jira_ticket_number_looked_up
      return @jira_ticket_number
    end
    if @pull.title =~ /\A((ruby|mongoid)-(\d+)) /i
      number = $3.to_i
    else
      number = nil
      sources = [@pull.body] + @pull.comments.map(&:body)
      sources.each do |body|
        if body =~ /#{jira_project}-(\d+)/i
          if number
            raise "Confusing ticket situation"
          end
          number = $1.to_i
        end
      end
    end
    if number.nil?
      if @pull.head_ref.to_i.to_s == @pull.head_ref
        number = @pull.head_ref.to_i
      end
    end
    @jira_ticket_number_looked_up = true
    @jira_ticket_number = number
  end

  def jira_issue_key!
    number = jira_ticket_number
    if number.nil?
      raise "Could not figure out jira ticket number"
    end
    "#{jira_project.upcase}-#{number}"
  end

  def fetch_results
    status = top_evergreen_status
    return unless status

    api_version = status.evergreen_version

    version = EgVersion.where(id: api_version.id).first
    version ||= EgVersion.new(id: api_version.id)
    basenames = version.rspec_json_basenames || Set.new

    api_version.builds.each do |build|
      build.tasks.each do |task|
        task.artifacts.each do |artifact|
          if artifact.name == 'rspec.json'
            ArtifactCache.instance.fetch_artifact(artifact.url)
            basenames << basename
          end
        end
      end
    end

    # must write the field due to mongoid limitation
    version.rspec_json_basenames = basenames
    version.save!
  end

  def aggregate_results
    version = EgVersion.find(top_evergreen_status.evergreen_version_id)
    version.rspec_json_basenames.each do |basename|
    end
  end
end
