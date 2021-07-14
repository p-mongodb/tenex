autoload :TicketedPrMaker, 'fe/pr_maker'
require 'fe/models/patch'

Routes.included do

  get '/repos' do
    @repos = Repo.all.sort_by(&:full_name)
    slim :repos
  end

  # repo
  get '/repos/:org/:repo' do |org_name, repo_name|
    @repo = Env.system_fe.hit_repo(org_name, repo_name)
    begin
      @pulls = gh_repo(org_name, repo_name).pulls(
        creator: params[:creator],
      )
    rescue Github::Client::ApiError => e
      if e.status == 404
        project = system_fe.evergreen_project_for_github_repo(org_name, repo_name)
        if project
          redirect "/projects/#{project.id}"
          return
        end
      end
      raise
    end
    @pulls.map! { |pull| PullPresenter.new(pull, eg_client, system_fe, @repo) }
    @jira_project = Mappings.repo_full_name_to_jira_project(@repo.full_name)
    slim :pulls
  end

  get '/repos/:org/:repo/settings' do |org_name, repo_name|
    @repo = system_fe.hit_repo(org_name, repo_name)
    @project = @repo.project
    slim :repo_settings
  end

  get '/repos/:org/:repo/workflow/:settting' do |org_name, repo_name, setting|
    @repo = system_fe.hit_repo(org_name, repo_name)
    @repo.workflow = setting == 'on'
    @repo.save!
    redirect "/repos/#{@repo.full_name}"
  end

  get '/repos/:org/:repo/create-project' do |org_name, repo_name|
    @repo = system_fe.hit_repo(org_name, repo_name)
    project = @repo.project
    if project.nil?
      project = Project.where(name: @repo.full_name).first
      if project && project.repo
        raise "Project already exists"
      end
      if project
        project.repo = @repo
        project.save!
      else
        project = Project.create!(repo: @repo, name: @repo.full_name)
      end
    end
    redirect "/projects/#{project.slug}"
  end

  get '/repos/:org/:repo/recent-branches' do |org_name, repo_name|
    @repo = system_fe.hit_repo(org_name, repo_name)
    rc = RepoCache.new('p-mongo', @repo.repo_name)
    rc.update_cache
    @branches = rc.recent_remote_branches(10)
    slim :recent_branches
  end

  get '/repos/:org/:repo/upstream-branches' do |org_name, repo_name|
    @repo = system_fe.hit_repo(org_name, repo_name)
    rc = RepoCache.new('mongodb', @repo.repo_name)
    rc.update_cache
    branches = rc.branches('-r').select do |name|
      name =~ /^origin\//
    end.map do |name|
      name.sub(/^origin\//, '')
    end.compact.reject do |name|
      %w(master HEAD).include?(name)
    end.sort_by do |branch_name|
      branch_name.sub(/-.*/, '').split('.').map { |c| c.to_i }
    end.reverse
    @branches = branches.map do |branch_name|
      BranchPresenter.new(name: branch_name, repo: @repo)
    end
    slim :upstream_branches
  end

  get '/repos/:org/:repo/branches/:branch/make-pr' do |org_name, repo_name, branch_name|
    @repo = system_fe.hit_repo(org_name, repo_name)
    if branch_name.to_i.to_s == branch_name
      pr_num = TicketedPrMaker.new(branch_name.to_i).make_pr
    else
      raise NotImplemented
    end
    redirect "/repos/#{@repo.full_name}/pulls/#{pr_num}"
  end

  get '/repos/:org/:repo/branches/:branch/submit-patch' do |org_name, repo_name, branch_name|
    @repo = system_fe.hit_repo(org_name, repo_name)
    branch_owner_name, branch_name = branch_name.split(':')
    rc = RepoCache.new('mongodb', @repo.repo_name)
    rc.update_cache
    rc.add_remote(branch_owner_name, repo_name)
    Dir.chdir(rc.cached_repo_path) do
      diff = rc.diff_to_master("#{branch_owner_name}/#{branch_name}")
      head_sha = rc.commitish_sha("#{branch_owner_name}/#{branch_name}")

      rv = eg_client.create_patch(
        project_id: @repo.evergreen_project_id,
        diff_text: diff,
        base_sha: rc.master_sha,
        description: "Branch: #{branch_owner_name}:#{branch_name}",
        variant_ids: ['all'],
        task_ids: ['all'],
        finalize: true,
      )

      patch_id = rv['patch']['Id']

      patch = Patch.create!(
        id: patch_id,
        head_branch_name: branch_name,
        base_branch_name: 'master',
        eg_project_id: @repo.evergreen_project_id,
        repo_id: @repo.id,
        head_sha: head_sha,
        eg_submission_result: rv,
      )
    end

    redirect "/repos/#{@repo.full_name}/upstream-branches"
  end
end
