class PullPresenter
  extend Forwardable

  def initialize(pull, eg_client)
    @pull = pull
    @eg_client = eg_client
  end

  attr_reader :pull
  attr_reader :eg_client
  def_delegators :@pull, :[]

  def statuses
    @statuses ||= @pull.statuses.map do |status|
      EvergreenStatusPresenter.new(status, @pull, eg_client)
    end
  end

  def take_status(label)
    status = statuses.detect { |s| s['context'] == label }
    if status
      @taken_statuses ||= {}
      @taken_statuses[status.context] = true
    end
    status
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
end
