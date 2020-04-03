require 'fe/child_process_helper'
require 'fe/env'

autoload :ProjectDetector, 'fe/project_detector'
autoload :RepoCache, 'fe/repo_cache'

class PatchBuildMaker
  include Env::Access

  def run(eg_project_id: nil)
    config = ProjectDetector.new.project_config
    eg_project_id ||= config.eg_project_name

    rc = RepoCache.new(config.gh_upstream_owner_name, config.gh_repo_name)
    rc.update_cache

    base_sha = rc.master_sha
    process, diff_text = ChildProcessHelper.get_output(%w(git diff upstream/master))

    patch = eg_client.create_patch(
      project_id: eg_project_id,
      base_sha: base_sha,
      diff_text: diff_text,
      finalize: true,
    )

    puts "Created #{patch.id}: #{patch.description}"
  end
end
