class BranchPresenter
  def initialize(name:, repo:)
    @name = name
    @repo = repo
  end

  attr_reader :name
  attr_reader :repo

  def html_url
    "https://github.com/#{repo.full_name}/tree/#{name}"
  end

  def head_sha
    @head_sha ||= begin
      rc = RepoCache.new(@repo.owner_name, @repo.repo_name)
      Dir.chdir(rc.cached_repo_path) do
        rc.commitish_sha("origin/#{name}")
      end
    end
  end

  def eg_patch
    if @patch.nil?
      @patch = Patch.where(repo_id: @repo.id, head_sha: head_sha).first
      if @patch.nil?
        @patch = false
      end
    end
    @patch || nil
  end
end
