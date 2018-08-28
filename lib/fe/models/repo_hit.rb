class RepoHit
  include Mongoid::Document

  belongs_to :repo
  field :created_at, type: Time
end
