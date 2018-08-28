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
