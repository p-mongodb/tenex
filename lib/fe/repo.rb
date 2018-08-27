require 'pathname'

class Repo
  def initialize(owner, name)
    @owner, @name = owner, name
  end

  attr_reader :owner, :name

  def full_name
    "#{owner}/#{name}"
  end

  def repos_path
    Pathname.new(File.expand_path('~/.cache/repos'))
  end

  def cached_repo_path
    repos_path.join(name)
  end

  def update_cache
    @cache_updated ||= begin
      FileUtils.mkdir_p(repos_path)
      if File.exist?(cached_repo_path)
        Dir.chdir(cached_repo_path) do
          ChildProcessHelper.check_call(%w(git reset --hard))
          ChildProcessHelper.check_call(%w(git checkout master))
          ChildProcessHelper.check_call(%w(git fetch origin))
          ChildProcessHelper.check_call(%w(git reset --hard origin/master))
        end
      else
        ChildProcessHelper.check_call(%W(git clone git@github.com:#{full_name}) + [cached_repo_path.to_s])
      end
      true
    end
  end

  def master_sha
    update_cache

    Dir.chdir(cached_repo_path) do
      output = ChildProcessHelper.check_output(%w(git show --pretty=oneline))
      output.strip.split(/\s/, 2).first
    end
  end
end
