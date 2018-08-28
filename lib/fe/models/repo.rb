class Repo
  include Mongoid::Document

  field :owner_name, type: String
  field :repo_name, type: String
  field :hit_count, type: Integer
  field :evergreen_project_id, type: String
  field :workflow, type: Boolean

  def full_name
    "#{owner_name}/#{repo_name}"
  end

  def repo_cache
    @repo_cache ||= RepoCache.new(owner_name, repo_name)
  end
end
