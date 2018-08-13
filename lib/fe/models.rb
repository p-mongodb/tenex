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

class SpawnedHost
  include Mongoid::Document
  include Mongoid::Timestamps

  field :distro_name, type: String
  field :key_name, type: String

  class << self
    def recent_distros
      order(created_at: -1).limit(10).pluck(:distro_name).uniq[0...5]
    end
  end
end

class Distro
  include Mongoid::Document

  field :name, type: String
end

class Key
  include Mongoid::Document

  field :name, type: String
end

class CacheState
  include Mongoid::Document

  field :distros_updated_at, type: Time
  field :keys_updated_at, type: Time

  def distros_ok?
    distros_updated_at && distros_updated_at > Time.now - 1.day
  end

  def keys_ok?
    keys_updated_at && keys_updated_at > Time.now - 1.day
  end
end
