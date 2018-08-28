class Pull
  include Mongoid::Document

  belongs_to :repo

  field :number, type: Integer
  field :head_owner_name, type: String
  field :head_repo_name, type: String
  field :head_branch_name, type: String
  field :base_branch_name, type: String
end
