class EgVersion
  include Mongoid::Document

  embeds_many :eg_artifacts
end
