require 'spec_helper'
require 'jirra/client'

describe Jirra::Client do
  let(:client) do
    described_class.new(site: 'https://jira.mongodb.org')
  end

  describe '#get_issue_fields' do
    context 'no optional arguments' do
      let(:result) do
        client.get_issue_fields('RUBY-1200')
      end

      it 'works' do
        result.should be_a(Hash)
        result['project']['key'].should == 'RUBY'
      end
    end

    context 'with fields listed' do
      let(:result) do
        client.get_issue_fields('RUBY-1205', fields: %w(summary))
      end

      it 'only returns requested fields' do
        result.should be_a(Hash)
        result['summary'].should =~ /Ruby MongoDB 3.6/
        result.keys.should == %w(summary)
      end
    end
  end
end
