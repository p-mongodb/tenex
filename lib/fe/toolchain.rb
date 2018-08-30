require 'fileutils'
require_relative './child_process_helper'

class Toolchain
  def latest_sha
    RepoCache.new('10gen', 'mongo-ruby-toolchain').master_sha
  end
end
