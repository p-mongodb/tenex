Routes.included do

  get '/jira/:project' do |project_name|
    @project_name = project_name.upcase
    @versions = jirra_client.project_versions(@project_name)
    @unreleased_versions = @versions.select do |version|
      !version['released']
    end
    slim :jira_project
  end

  get '/jira/:project/fixed/:version' do |project_name, version|
    @project_name = project_name.upcase
    if params[:exclusive]
      all_versions = jirra_client.project_versions(@project_name)
      versions = all_versions.select { |v| v['released'] }.sort_by do |version|
        version['releaseDate']
      end.reverse[0..4]
      @excluded_versions = versions
      extra_conds = versions.map { |v| %Q~and fixversion != "#{v['name']}"~ }.join(' ')
    else
      extra_conds = ''
    end
    res = jirra_client.jql(<<-jql, max_results: 500, fields: %w(summary description issuetype))
      project=#{@project_name}
      and fixversion=#{version}
      and (labels is empty or labels not in (no-changelog))
      #{extra_conds}
      order by type, priority desc, key
jql
    @issues = res.map do |info|
      OpenStruct.new(info)
    end
    @issues.sort_by! do |issue|
      case issue.fields['issuetype']['name']
      when 'Epic'
        1
      when 'New Feature'
        2
      when 'Improvement'
        3
      when 'Task'
        4
      when 'Bug'
        5
      else
        10
      end
    end
    slim :fixed_issues
  end

  get '/jira/:project/epics' do |project_name|
    project_name = project_name.upcase
    @issues = JIRA::Resource::Issue.jql(jira_client,
      "project=#{project_name} and type=epic order by resolution desc, updated desc",
      max_results: 50)
    slim :epics
  end

  get '/jira/:project/changelogs' do |project_name|
    @jira_project = project_name = project_name.upcase
    @versions = jirra_client.project_versions(project_name).select do |version|
      !version['released']
    end
    slim :changelogs
  end

  get '/jira/:project/:issue_key/no-changelog' do |project_name, issue_key|
    @project_name = project_name.upcase
    @issue_key = issue_key.upcase
    jirra_client.edit_issue(@issue_key, add_labels: %w(no-changelog))
    redirect return_path
  end

  get '/jira/editmeta' do
    @heading = 'Edit Meta'
    @payload = jirra_client.get_json('issue/RUBY-1690/editmeta')
    slim :editmeta
  end

  get '/jira/transitions' do
    @heading = 'Transitions'
    @payload = jirra_client.get_json('issue/RUBY-1690/transitions')
    slim :editmeta
  end

  get '/jira/statuses' do
    @heading = 'Statuses'
    @payload = jirra_client.get_json('project/RUBY/statuses')
    slim :editmeta
  end
end
