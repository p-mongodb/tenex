require 'fe/child_process_helper'

autoload :Jirra, 'jirra/client'

class PrMaker

  attr_reader :num, :repo_name, :jira_project, :jira_issue_key

  def make_pr
    begin
      pr_info = gh_client.post_json("/repos/mongodb/#{repo_name}/pulls",
        title: @title, head: "p-mongo:#{@branch_name}", base: 'master',
        body: @body, draft: true)
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

    if jira_project
      pr_url = "https://github.com/mongodb/#{repo_name}/pull/#{pr_num}"

      # https://developer.atlassian.com/server/jira/platform/jira-rest-api-for-remote-issue-links/
      payload = {
        globalId: "#{jira_project}-#{num}-pr-#{pr_num}",
        object: {
          url: pr_url,
          title: "Fix - PR ##{pr_num}",
          icon: {"url16x16":"https://github.com/favicon.ico"},
          status: {
            icon: {},
          },
        },
      }
      jirra_client.post_json("issue/#{jira_issue_key}/remotelink", payload)

      fields = jirra_client.get_issue_fields(jira_issue_key)
      status_name = fields['status']['name']
      if ['Needs Triage'].include?(status_name)
        jirra_client.transition_issue(jira_issue_key, 'In Progress',
          assignee: {name: ENV['JIRA_USERNAME']})
      end
    end

    pr_num
  end

  private def gh_client
    @gh_client ||= Github::Client.new(
        username: ENV['GITHUB_USERNAME'],
        auth_token: ENV['GITHUB_TOKEN'],
      )
  end

  private def jirra_client
    @jirra_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
      }

      Jirra::Client.new(options)
    end
  end

  private def repo_from_cwd
    dir = Dir.pwd
    until %w(. /).include?(dir)
      case File.basename(dir)
      when 'ruby-driver'
        @repo_name = 'mongo-ruby-driver'
        break
      when 'mongoid'
        @repo_name = 'mongoid'
        break
      end
      dir = File.dirname(dir)
    end
    if @repo_name.nil?
      raise ArgumentError, "Cannot figure out the project"
    end
  end
end

class TicketedPrMaker < PrMaker
  def initialize(num)
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
  def initialize(branch_name)
  end
end

class CurrentPrMaker < BranchPrMaker
  def initialize
    repo_from_cwd
    @num = nil
    @jira_project = nil

    branch_output = ChildProcessHelper.check_output(%w(git status))
    @branch_name = branch_output.split("\n").first.split(' ').last
    if @branch_name.strip.empty?
      raise ArgumentError, "Cannot figure out branch name"
    end

    commit_msg = ChildProcessHelper.check_output(%w(git show --pretty=%s -q))
    @title = commit_msg
    @body = ''

    ChildProcessHelper.check_call(['git', 'pp', @branch_name])
  end
end
