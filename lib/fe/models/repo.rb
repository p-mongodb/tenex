class Repo
  include Mongoid::Document

  field :owner_name, type: String
  field :repo_name, type: String
  field :hit_count, type: Integer
  field :evergreen_project_id, type: String
  field :evergreen_project_queried_at, type: Time
  field :workflow, type: Boolean
  field :evergreen, type: Boolean
  field :travis, type: Boolean

  has_many :pulls
  field :most_recent_pull_number, type: Integer

  def full_name
    "#{owner_name}/#{repo_name}"
  end

  def repo_cache
    @repo_cache ||= RepoCache.new(owner_name, repo_name)
  end

  def update_pulls(gh_client)
    gh_repo = Github::Repo.new(gh_client, owner_name, repo_name)
    first_number = nil
    gh_repo.each_pull(state: 'all') do |gh_pull|
      if self.most_recent_pull_number && gh_pull.number < self.most_recent_pull_number
        break
      end
      puts gh_pull.number
      first_number ||= gh_pull.number
      pull = Pull.where(repo: self, number: gh_pull.number).first
      if pull.nil?
        pull = Pull.new(
          repo: self, number: gh_pull.number,
        )
      end
      pull.head_owner_name = gh_pull.head_owner_name
      pull.head_repo_name = gh_pull.head_repo_name
      pull.head_branch_name = gh_pull.head_branch_name
      pull.base_branch_name = gh_pull.base_branch_name
      pull.save!
    end
    self.most_recent_pull_number = first_number
    save!
  end
end
