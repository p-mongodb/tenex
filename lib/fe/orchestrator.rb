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

  def link_issue_in_pr(pull: nil,
    org_name: nil, repo_name: nil, pr_num: nil,
    jira_issue_key: nil
  )
    pull ||= begin
      unless org_name && repo_name && pr_num
        raise ArgumentError, 'If pull is not given, org_name, repo_name and pr_num are required'
      end
      gh_client.repo(org_name, repo_name).pull(pr_num)
    end

    jira_issue_key ||= pull.jira_issue_key!

    url = "https://jira.mongodb.org/browse/#{jira_issue_key}"
    texts = [pull.body || ''] + pull.comments.map(&:body)
    if texts.any? { |text| text.include?(url) }
      # already added
    else
      if pull.body.nil? || pull.body.empty?
        pull.update(body: url)
      else
        pull.add_comment(url)
      end
    end
  end

  def link_issue_and_pr(pull:, org_name:, repo_name:, jira_issue_key:,
    pr_title: nil
  )
    link_issue_in_pr(pull: pull, org_name: org_name, repo_name: repo_name,
      jira_issue_key: jira_issue_key)
    link_pr_in_issue(org_name: org_name, repo_name: repo_name,
      pr_num: pull.number, pr_title: pr_title || pull.title,
      jira_issue_key: jira_issue_key)
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
    if ['Needs Triage', 'Investigating', 'Open', 'Scheduled', 'In Progress'].include?(status_name)
      # could raise Jirra::TransitionNotFound
      jirra_client.transition_issue(jira_issue_key, 'In Code Review',
        assignee: {name: ENV['JIRA_USERNAME']})
    end
  end
end
