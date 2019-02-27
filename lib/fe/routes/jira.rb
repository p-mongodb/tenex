module Routes
module Jira
  extend ActiveSupport::Concern

  included do

    get '/jira/:project' do |project_name|
      @project_name = project_name.upcase
      @versions = jirra_client.project_versions(@project_name)
      @unreleased_versions = @versions.select do |version|
        !version['released']
      end
      slim :jira_project
    end

    get '/jira/:project/fixed/:version' do |project_name, version|
      project_name = project_name.upcase
      @issues = JIRA::Resource::Issue.jql(jira_client,
        "project=#{project_name} and fixversion=#{version} order by type, priority desc, key",
        max_results: 500)
      slim :fixed_issues
    end

    get '/jira/:project/epics' do |project_name|
      project_name = project_name.upcase
      @issues = JIRA::Resource::Issue.jql(jira_client,
        "project=#{project_name} and type=epic order by resolution desc, updated desc",
        max_results: 50)
      slim :epics
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
end
end
