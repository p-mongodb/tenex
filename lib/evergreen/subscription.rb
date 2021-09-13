=begin
var (
        commitOrigin  = "commit"
        patchOrigin   = "patch"
        triggerOrigin = "trigger"
        triggerAdHoc  = "ad_hoc"
        gitTagOrigin  = "git_tag"
)

[{"id"=>"6026d6f2a4cf47705031120a",
  "resource_type"=>"TASK",
  "trigger"=>"failure",
  "selectors"=>
   [{"type"=>"project", "data"=>"drivers-atlas-testing"},
    {"type"=>"requester", "data"=>"gitter_request"}],
  "regex_selectors"=>[],
  "subscriber"=>{"type"=>"slack", "target"=>"@driver-leads-only"},
  "owner_type"=>"project",
  "owner"=>"drivers-atlas-testing",
  "trigger_data"=>{"failure-type"=>"any", "requester"=>"gitter_request"}},
 {"id"=>"613e9dc9e3c3312a36b8b736",
  "resource_type"=>"TASK",
  "trigger"=>"outcome",
  "selectors"=>
   [{"type"=>"project", "data"=>"drivers-atlas-testing"},
    {"type"=>"requester", "data"=>"gitter_request"}],
  "regex_selectors"=>[],
  "subscriber"=>{"type"=>"jira-comment", "target"=>"RUBY-2787"},
  "owner_type"=>"project",
  "owner"=>"drivers-atlas-testing",
  "trigger_data"=>{"requester"=>"gitter_request"}},
 {"id"=>"613e9dc9e3c3312a36b8b737",
  "resource_type"=>"TASK",
  "trigger"=>"outcome",
  "selectors"=>
   [{"type"=>"project", "data"=>"drivers-atlas-testing"},
    {"type"=>"requester", "data"=>"ad_hoc"}],
  "regex_selectors"=>[],
  "subscriber"=>{"type"=>"jira-comment", "target"=>"RUBY-2787"},
  "owner_type"=>"project",
  "owner"=>"drivers-atlas-testing",
  "trigger_data"=>{"failure-type"=>"any", "requester"=>"ad_hoc"}},
 {"id"=>"613e9e69e3c3312a36b8bade",
  "resource_type"=>"BUILD",
  "trigger"=>"outcome",
  "selectors"=>
   [{"type"=>"project", "data"=>"drivers-atlas-testing"},
    {"type"=>"requester", "data"=>"patch_request"}],
  "regex_selectors"=>[],
  "subscriber"=>{"type"=>"jira-comment", "target"=>"RUBY-2787"},
  "owner_type"=>"project",
  "owner"=>"drivers-atlas-testing",
  "trigger_data"=>{"requester"=>"patch_request"}}]

=end

module Evergreen
  class Subscription
    def initialize(client, info:, project:)
      @client = client
      @info = IceNine.deep_freeze(info)
      @project = project
    end

    attr_reader :client, :info, :project
  end
end

