require 'spec_helper'
require 'fe/jira_query_builder'

describe JiraQueryBuilder do
  describe '#expanded_query' do
    let(:builder) { described_class.new(query) }
    let(:expanded_actual) { builder.expanded_query }

    CASES = {
      'ruby open' => 'project in (ruby) and resolution in (unresolved)',
      'mongoid open' => 'project in (mongoid) and resolution in (unresolved)',
      'server rme' => 'project in (server) and reporter = currentUser()',
    }

    CASES.each do |smart_query, expected_expanded_query|
      q = smart_query

      context "smart query: #{smart_query}" do
        let(:query) { q }

        it 'expands correctly' do
          expanded_actual.should == expected_expanded_query
        end
      end
    end
  end
end
