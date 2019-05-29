class RecentWikiPage
  include Mongoid::Document
  include Mongoid::Timestamps

  field :space_name, type: String
  field :title, type: String
  field :last_hit_at, type: Time
end
