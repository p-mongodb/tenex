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
end
