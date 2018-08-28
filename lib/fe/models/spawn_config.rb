class SpawnConfig
  include Mongoid::Document

  field :last_distro_name, type: String
  field :last_key_name, type: String
end
