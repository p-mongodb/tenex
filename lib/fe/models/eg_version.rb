class EgVersion
  include Mongoid::Document

  field :rspec_json_basenames, type: Set
end
