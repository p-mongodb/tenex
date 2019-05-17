class Orchestrator
  include Env::Access

  def link_pr_to_issue(repo_name:, pr_num:, jira_issue_key:)
    pr_url = "https://github.com/mongodb/#{repo_name}/pull/#{pr_num}"

    # https://developer.atlassian.com/server/jira/platform/jira-rest-api-for-remote-issue-links/
    payload = {
      globalId: "#{jira_issue_key}-pr-#{pr_num}",
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
  end

  def transition_issue_to_in_progress(jira_issue_key)
    fields = jirra_client.get_issue_fields(jira_issue_key)
    status_name = fields['status']['name']
    if ['Needs Triage', 'Open'].include?(status_name)
      jirra_client.transition_issue(jira_issue_key, 'In Progress',
        assignee: {name: ENV['JIRA_USERNAME']})
    end
  end
end
