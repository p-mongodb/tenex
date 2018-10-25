class System
  def initialize(eg_client, gh_client)
    @eg_client, @gh_client = eg_client, gh_client
  end

  attr_reader :eg_client, :gh_client

  def newest_evergreen_version(version)
    return nil unless version
    project = evergreen_project_for_github_repo(
      version.pr_info[:owner_name], version.pr_info[:repo_name])
    project.recent_patches.detect do |patch|
      patch.description == version.message
    end
  end

  def evergreen_project_for_github_repo(owner_name, repo_name)
    repo = Repo.find_or_create_by(owner_name: owner_name, repo_name: repo_name)
    if repo.evergreen_project_id.nil? && !repo.evergreen_project_queried_at?
      project = eg_client.project_for_github_repo(owner_name, repo_name)
      if project
        repo.evergreen_project_id = project.id
      end
      repo.evergreen_project_queried_at = Time.now
      repo.save!
    end
    Evergreen::Project.new(eg_client, repo.evergreen_project_id)
  end

  def evergreen_project_for_github_repo!(owner_name, repo_name)
    evergreen_project_for_github_repo(owner_name, repo_name).tap do |p|
      raise "No project for #{owner_name}/#{repo_name}" unless p
    end
  end

  def hit_repo(owner_name, repo_name)
    repo = Repo.find_or_create_by(owner_name: owner_name, repo_name: repo_name)
    RepoHit.create!(repo: repo)
    repo.hit_count = RepoHit.where(repo: repo).count
    repo.save!
    repo
  end
end
