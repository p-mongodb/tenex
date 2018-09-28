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
          ChildProcessHelper.check_call(%w(git fetch p))
          ChildProcessHelper.check_call(%w(git reset --hard origin/master))
        end
      else
        ChildProcessHelper.check_call(%W(git clone git@github.com:#{full_name}) + [cached_repo_path.to_s])
        Dir.chdir(cached_repo_path) do
          ChildProcessHelper.check_call(%W(git remote add p git@github.com:p-mongo/#{name} -f))
        end
      end
      true
    end
    self
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
      line !~ /->/ && line =~ /^p\//
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
          git show p/#{branch}
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

  def commitish_time(commitish)
    output = Dir.chdir(cached_repo_path) do
      ChildProcessHelper.check_output(%W(
        git show #{commitish}
      ))
    end
    if output =~ /Date: \s+(.+)/
      date = $1
    else
      raise "No date"
    end
    Time.parse(date)
  end

  def commitish_message(commitish)
    output = Dir.chdir(cached_repo_path) do
      ChildProcessHelper.check_output(%W(
        git show -q #{commitish}
      ))
    end
    output.sub!(/\A.*\n.*\n.*\n\n/, '')
    output.gsub!(/^    /, '')
    output.split("\n", 2)
  end

  def rebase(pull)
    branch_name = pull.head_branch_name
    Dir.chdir(cached_repo_path) do
      ChildProcessHelper.check_call(['sh', '-c', <<-CMD])
        (git rebase --abort || true) &&
        git checkout master &&
        (git branch -D #{branch_name} || true) &&
        git checkout -b #{branch_name} --track p/#{branch_name} &&
        git rebase master &&
        git push -f
CMD
    end
  end

  def reword(pull)
    branch_name = pull.head_branch_name
    Dir.chdir(cached_repo_path) do
      if cached_repo_path.to_s =~ /mongoid/
        project = 'mongoid'
      else
        project = 'ruby'
      end

      ticket = nil
      if branch_name =~ /#{project}/
        ticket = branch_name
      elsif branch_name =~ /^(\d+)($|-)/
        ticket = "#{project}-#{$1}"
      else
        pull.comments.each do |comment|
          if comment.body =~ /#{project}-(\d+)/i
            if ticket
              raise "Confusing ticket situation"
            end
            ticket = "#{project}-#{$1}"
          end
        end
      end

      unless ticket
        raise "Could not figure out the ticket"
      end

      ChildProcessHelper.check_call(['sh', '-c', <<-CMD])
        git checkout master &&
        (git branch -D #{branch_name} || true) &&
        git checkout -b #{branch_name} --track p/#{branch_name} &&
        $HOME/apps/dev/script/reword #{ticket}
CMD
    end
  end
end
