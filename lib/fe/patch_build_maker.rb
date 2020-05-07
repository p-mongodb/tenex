require 'fe/child_process_helper'
require 'fe/env'

autoload :ProjectDetector, 'fe/project_detector'
autoload :RepoCache, 'fe/repo_cache'
autoload :Byebug, 'byebug'
autoload :FileUtils, 'fileutils'

class PatchBuildMaker
  include Env::Access

  def run(eg_project_id: nil, force: false)
    config = ProjectDetector.new.project_config
    eg_project_id ||= config.eg_project_name

    rc = RepoCache.new(config.gh_upstream_owner_name, config.gh_repo_name)
    rc.update_cache

    base_sha = rc.master_sha
    process, diff_text = ChildProcessHelper.get_output(%w(git diff upstream/master))
    diff_text.force_encoding('utf-8')

    # Verify valid utf-8
    diff_text.encode('utf-16')

    patch_path = Pathname.new(File.expand_path('~/.cache/patches')).join(eg_project_id + '.patch')
    FileUtils.mkdir_p(patch_path.dirname)
    File.open(patch_path, 'w') do |f|
      f << diff_text
    end
    puts "Saved patch to #{patch_path}"

=begin
    if force
      begin
        diff_text.encode('utf-16')
      rescue
        raise e.class
      end
    end
=end

    patch = eg_client.create_patch(
      project_id: eg_project_id,
      base_sha: base_sha,
      diff_text: diff_text,
      finalize: true,
    )

    puts "Created #{patch.id}: #{patch.description}"
  end
end
