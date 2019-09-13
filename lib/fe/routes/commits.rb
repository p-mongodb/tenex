Routes.included do

  get '/repos/:org/:repo/pulls/:id/rebase' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.rebase(@pull)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/reword' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.reword(@pull, jirra_client)
    subject, message = rc.commitish_message(@pull.head_branch_name)
    @pull.update(title: subject, body: message)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/edit-msg' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    subject, message = rc.commitish_message(@pull.head_sha)
    @message = "#{subject}\n\n#{message}"

    @branch_name = @pull.head_branch_name
    slim :edit_msg
  end

  post '/repos/:org/:repo/pulls/:id/edit-msg' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    new_message = params[:message]
    rc.set_commit_message(@pull, new_message)

    if params[:update_pr] == '1'
      subject, message = new_message.gsub("\r\n", "\n").split("\n\n", 2)
      if subject.length > 100
        extra = subject[100...subject.length]
        subject = subject[0...100] + '...'
        message = "#{extra}\n\n#{message}"
      end
      @pull.update(title: subject, body: message)
    end

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end
end
