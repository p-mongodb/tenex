require 'fe/child_process_helper'
require 'fe/env'

autoload :Jirra, 'jirra/client'
autoload :Orchestrator, 'fe/orchestrator'

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

  private def repo_from_cwd
    dir = Dir.pwd
    until %w(. /).include?(dir)
      case File.basename(dir)
      when 'ruby-driver'
        @repo_name = 'mongo-ruby-driver'
        @jira_project = 'RUBY'
        break
      when 'mongoid'
        @repo_name = 'mongoid'
        @jira_project = 'MONGOID'
        break
      when 'specifications'
        @repo_name = 'specifications'
        @jira_project ||= 'SPEC'
        break
      end
      dir = File.dirname(dir)
    end
    if @repo_name.nil?
      raise ArgumentError, "Cannot figure out the project"
    end
  end

  private def orchestrator
    @orchestrator ||= Orchestrator.new
  end
end

class TicketedPrMaker < PrMaker
  def initialize(num, options=nil)
    @options = options || {}

    @num = num

    @config = if num > 2000
      @repo_name = 'mongoid'
      @jira_project = 'mongoid'
    else
      @repo_name = 'mongo-ruby-driver'
      @jira_project = 'ruby'
    end

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

    repo_from_cwd
    @num = nil
    @jira_project = nil

    branch_output = ChildProcessHelper.check_output(%w(git status))
    @branch_name = branch_output.split("\n").first.split(' ').last
    if @branch_name.strip.empty?
      raise ArgumentError, "Cannot figure out branch name"
    end

    if @branch_name =~ /^spec-\d+$/i
      @jira_project = 'SPEC'
      @jira_issue_key = @branch_name.upcase
    elsif @branch_name =~ /^writing-\d+$/i
      @jira_project = 'WRITING'
      @jira_issue_key = @branch_name.upcase
    end

    commit_msg = ChildProcessHelper.check_output(%w(git show --pretty=%s -q))
    @title = commit_msg
    @body = ''

    ChildProcessHelper.check_call(['git', 'pp', @branch_name])
  end
end
