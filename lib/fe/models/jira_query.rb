class JiraQuery
  include Mongoid::Document
  include Mongoid::Timestamps

  field :input_text, type: String
  
  def self.recent
    all.sort(updated_at: -1).limit(20)
  end
end
