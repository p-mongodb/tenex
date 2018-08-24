require 'fileutils'
require_relative './child_process_helper'

class Toolchain
  def latest_sha
    repos_path = File.expand_path('~/.cache/repos')
    FileUtils.mkdir_p(repos_path)
    repos_path = Pathname.new(repos_path)
    if File.exist?(toolchain_path = repos_path.join('toolchain'))
      Dir.chdir(toolchain_path) do
        ChildProcessHelper.check_call(%w(git reset --hard))
        ChildProcessHelper.check_call(%w(git checkout master))
        ChildProcessHelper.check_call(%w(git fetch origin))
        ChildProcessHelper.check_call(%w(git reset --hard origin/master))
      end
    else
      ChildProcessHelper.check_call(%W(git clone git@github.com:10gen/mongo-ruby-toolchain) + [toolchain_path])
    end

    Dir.chdir(toolchain_path) do
      output = ChildProcessHelper.check_output(%w(git show --pretty=oneline))
      output.strip.split(/\s/, 2).first
    end
  end
end
