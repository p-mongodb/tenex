class EgVersion
  include Mongoid::Document

  field :rspec_json_urls, type: Set
end
