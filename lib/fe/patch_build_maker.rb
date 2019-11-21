require 'fe/child_process_helper'
require 'fe/env'

autoload :ProjectDetector, 'fe/project_detector'

class PatchBuildMaker
  include Env::Access

  def run
    config = ProjectDetector.new.project_config

    rc = RepoCache.new(config.gh_upstream_owner_name, config.gh_repo_name)
    rc.update_cache

    base_sha = rc.master_sha

    p eg_client.create_patch(
      project_id: config.eg_project_name,
      base_sha: base_sha,
      diff_text: ChildProcessHelper.get_output(%w(git diff upstream/master)),
      finalize: true,
    )
  end
end
