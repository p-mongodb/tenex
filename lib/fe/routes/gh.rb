Routes.included do

  get '/repos' do
    @repos = Repo.all.sort_by(&:full_name)
    slim :repos
  end

  # repo
  get '/repos/:org/:repo' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    begin
      @pulls = gh_repo(org_name, repo_name).pulls(
        creator: params[:creator],
      )
    rescue Github::Client::ApiError => e
      if e.status == 404
        project = system.evergreen_project_for_github_repo(org_name, repo_name)
        if project
          redirect "/projects/#{project.id}"
          return
        end
      end
      raise
    end
    @pulls.map! { |pull| PullPresenter.new(pull, eg_client, system, @repo) }
    slim :pulls
  end

  get '/repos/:org/:repo/settings' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    slim :repo_settings
  end

  get '/repos/:org/:repo/workflow/:settting' do |org_name, repo_name, setting|
    @repo = system.hit_repo(org_name, repo_name)
    @repo.workflow = setting == 'on'
    @repo.save!
    redirect "/repos/#{@repo.full_name}"
  end

  get '/repos/:org/:repo/create-project' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    project = @repo.project
    if project.nil?
      project = Project.create!(repo: @repo, name: @repo.full_name)
    end
    redirect "/projects/#{project.slug}"
  end

  get '/repos/:org/:repo/recent-branches' do |org_name, repo_name|
    @repo = system.hit_repo(org_name, repo_name)
    rc = RepoCache.new('p-mongo', @repo.repo_name)
    rc.update_cache
    @branches = rc.recent_remote_branches(10)
    slim :branches
  end
end
