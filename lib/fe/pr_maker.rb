require 'fe/child_process_helper'
require 'fe/env'

autoload :Jirra, 'jirra/client'
autoload :Orchestrator, 'fe/orchestrator'

class CannotDetermineProject < StandardError
end

ProjectConfig = Struct.new(
  :gh_upstream_owner_name,
  :gh_repo_name,
  :jira_project,
)

PROJECT_CONFIGS = {
  'mongo-ruby-driver' => ProjectConfig.new(
    'mongodb',
    'mongo-ruby-driver',
    'RUBY',
  ),
  'mongoid' => ProjectConfig.new(
    'mongodb',
    'mongoid',
    'MONGOID',
  ),
  'bson-ruby' => ProjectConfig.new(
    'mongodb',
    'bson-ruby',
    'RUBY',
  ),
  'mongo-ruby-kerberos' => ProjectConfig.new(
    'mongodb',
    'mongo-ruby-kerberos',
    'RUBY',
  ),
  'specifications' => ProjectConfig.new(
    'mongodb',
    'specifications',
    'SPEC',
  ),
  'writing' => ProjectConfig.new(
    'mongodb',
    'specifications',
    'WRITING',
  ),
}

class ProjectDetector
  def initialize(path = nil)
    path ||= Dir.pwd

    until @repo_name || %w(. /).include?(path)
      case basename = File.basename(path)
      when 'ruby-driver', 'mongoid', 'specifications', 'bson-ruby'
        key = basename
        break
      when 'krb'
        key = 'mongo-ruby-kerberos'
        break
      when 'source'
        if File.basename(File.dirname(dir)) == 'specifications'
          key = 'specifications'
          break
        end
      end
      dir = File.dirname(dir)
    end

    @project_config = PROJECT_CONFIGS[key]

    if project_config.nil?
      raise CannotDetermineProject, "Cannot figure out the project"
    end
  end

  attr_reader :project_config
end

class PrMaker
  include Env::Access

  attr_reader :num, :repo_name, :jira_project, :jira_issue_key

  def make_pr
    unless repo_name
      raise 'Cannot make a PR when repo name is not known'
    end
    begin
      pr_info = gh_client.create_pr('mongodb', repo_name,
        title: @title, head: "p-mongo:#{@branch_name}", body: @body)
      pr_num = pr_info['number']
    rescue Github::Client::ApiError => e
      if e.status == 422
        if e.body =~ /already exists/
          pulls = gh_client.repo('mongodb', repo_name).pulls
          pr_num = nil
          pulls.each do |pull|
            if pull.head_label == "p-mongo:#{@branch_name}"
              pr_num = pull.number
              break
            end
          end
          if pr_num.nil?
            raise
          end
        else
          raise
        end
      else
        raise
      end
    end

    if jira_project && jira_issue_key
      orchestrator.link_pr_to_issue(repo_name: repo_name,
        pr_num: pr_num, jira_issue_key: jira_issue_key)

      orchestrator.transition_issue_to_in_progress(jira_issue_key)
    end

    pr_num
  end

  private def orchestrator
    @orchestrator ||= Orchestrator.new
  end
end

class TicketedPrMaker < PrMaker
  def initialize(num, options=nil)
    @options = options || {}

    @num = num

    begin
      @project = ProjectDetector.new.project
    rescue CannotDetermineProject
      if num > 2500
        @project = ProjectDetector.force('mongoid')
      else
        @project = ProjectDetector.force('mongo-ruby-driver')
      end
    end

    @repo_name = @project.gh_repo_name
    @jira_project = @project.jira_project

    @branch_name = num.to_s
    @jira_project.upcase!
    @jira_issue_key = "#{@jira_project}-#{@num}"

    info = jirra_client.get_json("issue/#{@jira_issue_key}")
    @title = "#{@jira_issue_key} #{info['fields']['summary']}"
    @body = "https://jira.mongodb.com/browse/#{@jira_issue_key}"
  end
end

class BranchPrMaker < PrMaker
  #def initialize(branch_name, options=nil)
  #end
end

class CurrentPrMaker < BranchPrMaker
  def initialize(options=nil)
    @options = options || {}

    config = ProjectDetector.new.project_config
    @num = nil

    branch_output = ChildProcessHelper.check_output(%w(git status))
    @branch_name = branch_output.split("\n").first.split(' ').last
    if @branch_name.strip.empty?
      raise ArgumentError, "Cannot figure out branch name"
    end

    if @branch_name =~ /^spec-\d+$/i
      config = PROJECT_CONFIGS['specifications']
    elsif @branch_name =~ /^writing-\d+$/i
      config = PROJECT_CONFIGS['writing']
    end

    if @branch_name =~ /^(\d+)/
      @num = $1
    end

    @repo_name = config.gh_repo_name
    @jira_project = config.jira_project

    commit_msg = ChildProcessHelper.check_output(%w(git show --pretty=%s -q))
    @title = commit_msg
    unless @title =~ /^#{config.jira_project}-#{@num}\b/
      @title = "#{config.jira_project}-#{@num} #{@title}"
    end
    @body = "https://jira.mongodb.com/browse/#{@jira_project}-#{@num}"

    cmd = ['git', 'pp', @branch_name]
    username = ChildProcessHelper.check_output(%w(id -un)).strip
    if username == 'me'
      cmd = %w(sudo -u mpush) + cmd
    end
    ChildProcessHelper.check_call(cmd)
  end
end
