class EgBuild
  include Mongoid::Document

  field :log_url, type: String
  field :finished_at, type: Time
  field :task_log_url, type: String
end
