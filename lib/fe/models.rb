require 'mongoid'

class Repo
  include Mongoid::Document

  field :owner_name, type: String
  field :repo_name, type: String
  field :hit_count, type: Integer
end

class RepoHit
  include Mongoid::Document

  belongs_to :repo
  field :created_at, type: Time
end
