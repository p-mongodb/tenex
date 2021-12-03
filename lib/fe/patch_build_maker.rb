require 'fe/child_process_helper'
require 'fe/env'

autoload :ProjectDetector, 'fe/project_detector'
autoload :EgProjectResolver, 'fe/project_detector'
autoload :RepoCache, 'fe/repo_cache'
autoload :Byebug, 'byebug'
autoload :FileUtils, 'fileutils'

class PatchBuildMaker
  include Env::Access

  def initialize(**opts)
    @options = opts.freeze
  end

  attr_reader :options

  %i(eg_project_id force priority).each do |attr|
    define_method(attr) do
      options[attr]
    end
  end

  def base_branch
    options[:base_branch] || 'upstream/master'
  end

  def eg_project_config
    @eg_project_config ||= if eg_project_id
      EgProjectResolver.new(eg_project_id).project_config
    else
      ProjectDetector.new.project_config
    end.tap do |v|
      @eg_project_id ||= v.eg_project_names.first
    end
  end

  def submit
    config = eg_project_config

    eg_config = eg_client.project_by_id(config.eg_project_name)
    config_file_path = eg_config.config_file_path

    contents = File.read(config_file_path)
    validator = Evergreen::ParserValidator.new(contents)
    validator.validate!

    rc = RepoCache.new(config.gh_upstream_owner_name, config.gh_repo_name)
    rc.update_cache

    base_sha = rc.commitish_sha(base_branch)
    remote_name = if rc.remote_names.include?('upstream')
      'upstream'
    else
      'origin'
    end
    ChildProcessHelper.check_call(['git', 'fetch', remote_name])

    if options[:full]
      ChildProcessHelper.check_call(%W(
        rsync -a --exclude .git --delete .
      ) + [rc.cached_repo_path.to_s])

      ChildProcessHelper.check_call(%W(
        git add .
      ), cwd: rc.cached_repo_path)

      diff_text = get_diff_text(cmd: %w(git diff --binary --cached), cwd: rc.cached_repo_path)
    else
      diff_text = get_diff_text

      patch_path = Pathname.new(File.expand_path('~/.cache/patches')).join(@eg_project_id + '.patch')
      FileUtils.mkdir_p(patch_path.dirname)
      File.open(patch_path, 'w') do |f|
        f << diff_text
      end
      puts "Saved patch to #{patch_path}"

      # Occasionally the output of `git diff` does not apply back to the base
      # using git apply, if the output was actually caculated against an old
      # (e.g. outdated) base.
      puts "Trying to apply the patch back to the base"
      ChildProcessHelper.check_call(%W(
        git apply --stat
      ) + [patch_path.to_s])
      rc.checkout(base_branch)
      rc.apply_patch(patch_path)
    end

    create_patch(base_sha, diff_text)
  end

  def get_diff_text(cmd: %w(git diff --binary) + [base_branch + '...'], cwd: nil)
    process, diff_text = ChildProcessHelper.get_output(cmd, cwd: cwd)
    diff_text.force_encoding('utf-8')

    # Verify valid utf-8
    diff_text.encode('utf-16')

    diff_text
  end

  def create_patch(base_sha, diff_text)
    patch = eg_client.create_patch(
      project_id: @eg_project_id,
      base_sha: base_sha,
      diff_text: diff_text,
      finalize: true,
      description: options[:message],
    )

    puts "Created #{patch.id}: #{patch.description}"

    if priority
      puts "Setting priority to #{priority}"

      patch.set_priority(priority)
    end
  end
end
