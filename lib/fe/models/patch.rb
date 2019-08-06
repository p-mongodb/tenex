class Patch
  include Mongoid::Document

  field :head_sha, type: String
  field :base_branch_name, type: String
  field :head_branch_name, type: String
  field :created_at, type: Time
  field :eg_project_id, type: String
  field :gh_pull_id, type: Integer

  belongs_to :repo
end
