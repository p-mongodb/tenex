class EgTask
  include Mongoid::Document

  # This is the evergreen task id
  field :id, type: String
  field :build_id, type: String

  field :title, type: String
  field :log_url, type: String
  field :finished_at, type: Time
  field :task_log_url, type: String

  # Zero-based line index of first failure, if any
  field :first_failure_index, type: Integer
  # Zero-based line index where detected mongo-orchestration curl failure
  # starts, if any
  field :mo_curl_failure_index, type: Integer
  # Zero-based line index where detected bundler failure starts, if any
  field :bundler_failure_index, type: Integer
end
