module Globals

  def gh_repo(org_name, repo_name)
    gh_client.repo(org_name, repo_name)
  end

  def system
    System.new(eg_client, gh_client)
  end
end
