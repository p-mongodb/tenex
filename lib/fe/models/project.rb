class Project
  include Mongoid::Document

  field :name, type: String
  field :slug, type: String
  field :workflow, type: Boolean
  field :evergreen, type: Boolean
  field :travis, type: Boolean
  field :evergreen_project_id, type: String
  field :evergreen_project_queried_at, type: Time
  field :gh_upstream_owner_name, type: String
  field :gh_repo_name, type: String
  field :jira_project, type: String

  has_one :repo

  before_validation :set_slug, on: :create

  private

  def set_slug
    if slug.nil?
      self.slug = name.gsub(/[^\w]/, '-').gsub(/-+/, '-').sub(/^-/, '').sub(/-$/, '')
    end
  end

  validates_presence_of :slug
  validates_uniqueness_of :slug
end
