class ReviewTimeAnalyzer
  def initialize(repo, gh_client)
    @repo = repo
    @gh_client = gh_client
  end

  attr_reader :gh_client

  def pulls
    @pulls ||= begin
      @repo.update_pulls(gh_client)
      @repo.pulls
    end
  end

  def run
    pulls
    byebug
    1
  end
end
