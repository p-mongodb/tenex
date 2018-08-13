require 'mongoid'

class Repo
  include Mongoid::Document

  field :owner_name, type: String
  field :repo_name, type: String
  field :hit_count, type: Integer
  field :evergreen_project_id, type: String
end

class RepoHit
  include Mongoid::Document

  belongs_to :repo
  field :created_at, type: Time
end

class SpawnConfig
  include Mongoid::Document

  field :last_distro_name, type: String
  field :last_key_name, type: String
end
