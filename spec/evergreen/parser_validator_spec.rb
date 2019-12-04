require 'spec_helper'
require 'evergreen/parser_validator'

CONFIG_ROOT = Pathname.new(File.dirname(__FILE__)).join('fixtures/config')

describe Evergreen::ParserValidator do
  let(:validator) do
    described_class.new(File.read(config_path))
  end

  let(:error_msg) { validator.errors.join("\n") }

  context 'task referencing missing function' do
    let(:config_path) { CONFIG_ROOT.join('task_ref_missing_fn.yml') }

    it 'fails' do
      error_msg.should =~ /references undefined function/
    end
  end
end
