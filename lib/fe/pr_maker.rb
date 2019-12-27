require 'fe/child_process_helper'
require 'fe/env'

autoload :Jirra, 'jirra/client'
autoload :Orchestrator, 'fe/orchestrator'
autoload :ProjectDetector, 'fe/project_detector'

class PrMaker
  include Env::Access

  attr_reader :num, :owner_name, :repo_name, :jira_project, :jira_issue_key

  def make_pr
    unless repo_name
      raise 'Cannot make a PR when repo name is not known'
    end
    begin
      pr_info = gh_client.create_pr(owner_name, repo_name,
        title: @title, head: "p-mongo:#{@branch_name}", body: @body)
      pr_num = pr_info['number']
    rescue Github::Client::ApiError => e
      if e.status == 422
        if e.body =~ /already exists/
          pulls = gh_client.repo(owner_name, repo_name).pulls
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
      orchestrator.link_pr_in_issue(repo_name: repo_name,
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
      config = ProjectDetector.new.project_config
    rescue CannotDetermineProject
      if num > 2500
        config = PROJECT_CONFIGS['mongoid']
      else
        config = PROJECT_CONFIGS['mongo-ruby-driver']
      end
    end

    @repo_name = config.gh_repo_name
    @owner_name = config.gh_upstream_owner_name || 'mongodb'
    @jira_project = config.jira_project

    @branch_name = num.to_s
    @jira_project.upcase!
    @jira_issue_key = "#{@jira_project}-#{@num}"

    fields = jirra_client.get_issue_fields(@jira_issue_key, fields: %w(summary))
    @title = "#{@jira_issue_key} #{fields['summary']}"
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
    @owner_name = config.gh_upstream_owner_name || 'mongodb'
    @jira_project = config.jira_project

    commit_msg = ChildProcessHelper.check_output(%w(git show --pretty=%s -q))
    @title = commit_msg
    if @num && @title !~ /^#{config.jira_project}-#{@num}\b/
      @title = "#{config.jira_project}-#{@num} #{@title}"
    end
    @body = if @num
      "https://jira.mongodb.com/browse/#{@jira_project}-#{@num}"
    else
      ''
    end

    cmd = ['git', 'pp', @branch_name]
    username = ChildProcessHelper.check_output(%w(id -un)).strip
    if username == 'me'
      cmd = %w(sudo -u mpush) + cmd
    end
    ChildProcessHelper.check_call(cmd)
  end
end
