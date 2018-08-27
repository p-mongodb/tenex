require 'pathname'
require 'time'

class RepoCache
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
          ChildProcessHelper.check_call(%w(git fetch pp))
          ChildProcessHelper.check_call(%w(git reset --hard origin/master))
        end
      else
        ChildProcessHelper.check_call(%W(git clone git@github.com:#{full_name}) + [cached_repo_path.to_s])
        Dir.chdir(cached_repo_path) do
          ChildProcessHelper.check_call(%W(git remote add pp git@github.com:p-mongo/#{name} -f))
        end
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

  def my_remote_branches
    update_cache

    output = Dir.chdir(cached_repo_path) do
      ChildProcessHelper.check_output(%W(
        git branch -r
      ))
    end

    lines = output.split(/\n/).map(&:strip).select do |line|
      line !~ /->/ && line =~ /^pp\//
    end

    lines.map do |line|
      line.sub(/.*\//, '')
    end
  end

  def recent_branches
    branches = my_remote_branches
    meta = {}
    branches.each do |branch|
      output = Dir.chdir(cached_repo_path) do
        ChildProcessHelper.check_output(%W(
          git show pp/#{branch}
        ))
      end
      sha = output.split(/\s+/)[1]
      if output =~ /Date: \s+(.+)/
        date = $1
      else
        raise "No date"
      end
      meta[branch] = Time.parse(date)
    end

    branches.select! do |branch|
      Time.now - meta[branch] < 1.day
    end

    branches.sort_by do |branch|
      meta[branch]
    end.reverse

    branches
  end
end
