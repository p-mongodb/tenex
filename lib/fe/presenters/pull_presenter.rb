require 'fe/artifact_cache'
require 'fe/aggregate_rspec_result'
require 'fe/mappings'

class PullPresenter
  extend Forwardable

  def initialize(pull, eg_client, system_fe, repo)
    @pull = pull
    @eg_client = eg_client
    @system_fe = system_fe
    @repo = repo
  end

  attr_reader :pull
  attr_reader :eg_client, :system_fe
  def_delegators :@pull, :[], :repo_full_name, :travis_statuses,
    :evergreen_version_id, :head_branch_name,
    :approved?, :review_requested?,
    :jira_project, :jira_ticket_number, :jira_issue_key!, :labels, :label_names

  def statuses
    # Sometimes statuses in github are duplicated, work around
    @statuses ||= begin
      statuses = @pull.statuses.map do |status|
        status = EvergreenStatusPresenter.new(status, @pull, eg_client, system_fe)
        if status.travis? && @repo.project && !@repo.project.travis?
          nil
        else
          status
        end
      end
      #.uniq { |item| item.build_id }
      statuses.compact.sort_by(&:name)
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
      status = EvergreenStatusPresenter.new(status, @pull, eg_client, system_fe)
    end
    status
  end

  def evergreen_version
    @evergreen_version ||= Evergreen::Version.new(eg_client, @pull.evergreen_version_id)
  end

  def evergreen_project_id?
    !!system_fe.evergreen_project_for_github_repo
  end

  def evergreen_project_id
    system_fe.evergreen_project_for_github_repo!(pull.repo_full_name.split('/').first, pull.repo_full_name.split('/')[1]).id
  end

  def have_rspec_json?
    return @have_rspec_json unless @have_rspec_json.nil?
    @have_rspec_json = !!statuses.detect do |status|
      status.finished? && status.rspec_json_url
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

  def fetch_results(**options)
    status = top_evergreen_status
    return unless status

    api_version = status.evergreen_version

    version = EgVersion.where(id: api_version.id).first
    version ||= EgVersion.new(id: api_version.id)

    load_artifacts(version, api_version, %w(rspec.json.gz rspec.json),
      failed: options[:failed])

    version.save!
  end

  def load_artifacts(eg_version, api_version, names, **options)
    dirty = false
    api_version.builds.each do |build|
      unless eg_version.eg_artifacts.where(build_id: build.id).any?
        build.tasks.each do |task|
          if options[:failed] && !task.failed?
            next
          end
          artifact = task.first_artifact_for_names(names)
          if artifact
            subdir = "#{Utils.md5(build.id)}-#{build.started_at.to_i}"
            ArtifactCache.instance.fetch_compressed_artifact(
              artifact.url, subdir: subdir)
            eg_artifact = EgArtifact.new(
              name: artifact.name,
              url: artifact.url,
              subdir: subdir,
              build_id: build.id,
              failed: build.failed?,
            )
            eg_version.eg_artifacts << eg_artifact
            dirty = true
          end
        end
      end
    end
    if dirty
      eg_version.save!
    end
  end

  def aggregate_result(failed: nil, &block)
    version = EgVersion.find(top_evergreen_status.evergreen_version_id)
    artifacts = version.eg_artifacts
    if failed
      artifacts = artifacts.where(failed: true)
    end
    AggregateRspecResult.new(artifacts, &block)
  end

  def patch
    if @patch.nil?
      @patch = Patch.where(gh_pull_id: pull.number,
        repo_id: @repo.id, head_sha: pull.head_sha).first
      if @patch.nil?
        @patch = false
      end
    end
    @patch || nil
  end
end
