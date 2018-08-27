require 'fileutils'
require_relative './child_process_helper'

class Toolchain
  def latest_sha
    Repo.new('10gen', 'mongo-ruby-toolchain').master_sha
  end
end
