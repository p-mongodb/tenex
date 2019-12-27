class Orchestrator
  include Env::Access

  def link_pr_in_issue(org_name: 'mongodb', repo_name:, pr_num:, pr_title: nil,
    jira_issue_key:
  )
    pr_url = "https://github.com/#{org_name}/#{repo_name}/pull/#{pr_num}"

    if pr_title.nil?
      pull = gh_client.repo(org_name, repo_name).pull(pr_num)
      pr_title = pull.title
    end

    jirra_client.add_issue_link(jira_issue_key,
      link_id: "#{jira_issue_key}-pr-#{pr_num}",
      url: pr_url,
      title: "#{repo_name} ##{pr_num}: #{pr_title}",
      icon: {"url16x16":"https://github.com/favicon.ico"},
    )
  end

  def transition_issue_to_in_progress(jira_issue_key)
    fields = jirra_client.get_issue_fields(jira_issue_key)
    status_name = fields['status']['name']
    if ['Needs Triage', 'Open', 'Scheduled'].include?(status_name)
      # could raise Jirra::TransitionNotFound
      jirra_client.transition_issue(jira_issue_key, 'In Progress',
        assignee: {name: ENV['JIRA_USERNAME']})
    end
  end

  def transition_issue_to_in_review(jira_issue_key)
    fields = jirra_client.get_issue_fields(jira_issue_key)
    status_name = fields['status']['name']
    if ['Needs Triage', 'Open', 'Scheduled', 'In Progress'].include?(status_name)
      # could raise Jirra::TransitionNotFound
      jirra_client.transition_issue(jira_issue_key, 'In Code Review',
        assignee: {name: ENV['JIRA_USERNAME']})
    end
  end
end
