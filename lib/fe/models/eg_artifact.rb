class EgArtifact
  include Mongoid::Document

  embedded_in :eg_version

  field :name, type: String
  field :url, type: String
  field :subdir, type: String
  field :build_id, type: String
  field :failed, type: Boolean
end
