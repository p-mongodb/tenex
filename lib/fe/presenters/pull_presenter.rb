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
    top_evergreen_status.passed?
  end
end
