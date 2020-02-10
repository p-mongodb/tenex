require 'spec_helper'
require 'evergreen/parser_validator'

CONFIG_ROOT = Pathname.new(File.dirname(__FILE__)).join('fixtures/config')

describe Evergreen::ParserValidator do
  let(:validator) do
    described_class.new(File.read(config_path))
  end

  let(:error_msg) { validator.errors.join("\n") }

  shared_examples_for 'succeeds' do
    it 'succeeds' do
      error_msg.should == ''
    end
  end

  context 'invalid yaml' do
    let(:config_path) { CONFIG_ROOT.join('invalid_yaml.yml') }

    it 'fails' do
      error_msg.should =~ /Failed to parse project file:.*SyntaxError:.*did not find expected node content.*at line 1/
    end
  end

  context 'task referencing missing function' do
    let(:config_path) { CONFIG_ROOT.join('task_ref_missing_fn.yml') }

    it 'fails' do
      error_msg.should =~ /references undefined function/
    end
  end

  context 'task referencing missing function and no functions are defined' do
    let(:config_path) { CONFIG_ROOT.join('task_ref_no_functions.yml') }

    it 'fails' do
      error_msg.should =~ /references undefined function/
      error_msg.should =~ /there are no functions defined/
    end
  end

  context 'task with space in name' do
    let(:config_path) { CONFIG_ROOT.join('task_name_space.yml') }

    it 'fails' do
      error_msg.should =~ /contains a space in its name/
    end
  end

  context 'ok function' do
    let(:config_path) { CONFIG_ROOT.join('function_ok.yml') }

    it_behaves_like 'succeeds'
  end

  context 'function containing data of wrong type' do
    let(:config_path) { CONFIG_ROOT.join('function_wrong_type.yml') }

    it 'fails' do
      error_msg.should =~ /Function.*contains data of wrong type/
    end
  end

  context 'function without a command' do
    let(:config_path) { CONFIG_ROOT.join('function_no_command.yml') }

    it 'fails' do
      error_msg.should =~ /Function.*does not have the.*command.*key/
    end
  end

  context 'axis name missing' do
    let(:config_path) { CONFIG_ROOT.join('axis_name_missing.yml') }

    it 'fails' do
      error_msg.should =~ /Build variant.*references nonexistent axis/
    end
  end

  context 'axis value missing' do
    let(:config_path) { CONFIG_ROOT.join('axis_value_missing.yml') }

    it 'fails' do
      error_msg.should =~ /Build variant.*references nonexistent value.*for axis/
    end
  end

  context 'axis value of *' do
    let(:config_path) { CONFIG_ROOT.join('axis_value_asterisk.yml') }

    it_behaves_like 'succeeds'
  end

end
