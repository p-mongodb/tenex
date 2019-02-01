class Toolchain
  def latest_sha
    RepoCache.new('10gen', 'mongo-ruby-toolchain').master_sha
  end
end
