Routes.included do

  # pull
  get '/repos/:org/:repo/pulls/:id' do |org_name, repo_name, id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @statuses = @pull.statuses

    #@pull.fetch_results
    #@pull.aggregate_result

    @configs = {
      'mongodb-version' => %w(4.0 3.6 3.4 3.2 3.0 2.6 latest),
      'topology' => %w(standalone replica-set sharded-cluster),
      'auth-and-ssl' => %w(noauth-and-nossl auth-and-ssl),
    }
    @ruby_versions = %w(2.6 2.5 2.4 2.3 2.2 1.9 head jruby-9.2 jruby-9.1)
    @table_keys = %w(mongodb-version topology auth-and-ssl ruby)
    @category_values = {}
    @table = {}
    @untaken_statuses = []
    @pull.statuses.each do |status|
      if repo_name == 'mongo-ruby-driver' && status.status.context =~ %r,evergreen/,
        id = status.status.context.split('/')[1]
        label, rest = id.split('__')
        meta = {}
        rest.split('_').each do |pair|
          key, value = pair.split('~')
          case key
          when 'ruby'
            meta[key] = value.sub(/^ruby-/, '')
          else
            meta[key] = value
          end
        end
        if label =~ /enterprise-auth-tests-ubuntu/
          meta['mongodb-version'] = 'EA'
          meta['topology'] = 'ubuntu'
        elsif label =~ /enterprise-auth-tests-rhel/
          meta['mongodb-version'] = 'EA'
          meta['topology'] = 'rhel'
        elsif label =~ /local-tls/
          meta['mongodb-version'] = meta['mongodb-version']
          meta['auth-and-ssl'] = 'TLS-verify'
        else
          meta['auth-and-ssl'] ||= 'noauth-and-nossl'
        end
        @table_keys.each do |key|
          value = meta[key]
          if value.nil?
            raise "Missing #{key} in #{meta}"
          end
          @category_values[key] ||= []
          (@category_values[key] << value).uniq!
        end
        meta_for_label = meta.dup
        map = @table_keys.inject(@table) do |map, key|
          (map[meta[key]] ||= {}).tap do
            meta_for_label.delete(key)
          end
        end
        short_label = ''
        if meta_for_label.delete('as')
          short_label << 'AS'
        end
        if meta_for_label.delete('lint')
          short_label << 'L'
        end
        if meta_for_label.delete('retry-reads')
          short_label << 'RR'
        end
        if meta_for_label.delete('retry-writes')
          short_label << 'RW'
        end
        if meta_for_label.delete('single-mongos')
          short_label << 'SM'
        end
        if meta_for_label.delete('storage-engine') == 'mmapv1'
          short_label << 'mmap'
        end
        if compressor = meta_for_label.delete('compressor')
          short_label << compressor[0].upcase
        end
        if meta_for_label.empty?
          if short_label.empty?
            short_label = '*'
          end
        else
          extra = meta_for_label.map { |k, v| "#{k}=#{v}" }.join(',')
          if short_label.empty?
            short_label = extra
          else
            short_label += '; ' + extra
          end
        end
        if map[short_label]
          raise "overwrite for #{short_label} #{meta.inspect}"
        end
        map[short_label] = status
      else
        @untaken_statuses << status
      end
    end
    if repo_name == 'mongo-ruby-driver' && @category_values
      @category_values['ruby']&.sort! do |a, b|
        if a =~ /^[0-9]/ && b =~ /^[0-9]/ || a =~ /^j/ && b =~ /^j/
          b <=> a
        else
          a <=> b
        end
      end
      @category_values['mongodb-version']&.sort! do |a, b|
        if a =~ /^[0-9]/ && b =~ /^[0-9]/
          b <=> a
        else
          a <=> b
        end
      end
      @category_values['mongodb-version']&.delete('EA')
      @category_values['mongodb-version']&.push('EA')
      if @category_values['topology']
        @category_values['topology'] = %w(standalone replica-set sharded-cluster rhel ubuntu)
      end
    end
    if @category_values.empty?
      @category_values = nil
    end

    @branch_name = @pull.head_branch_name
    @current_eg_project_id = @pull.evergreen_project_id
    slim :pull
  end

  # pull perf
  get '/repos/:org/:repo/pulls/:id/perf' do |org_name, repo_name, id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @statuses = @pull.statuses.sort_by do |status|
      if status.build_id.nil?
        # top level build
        -1000000
      else
        -status.time_taken
      end
    end
    @branch_name = @pull.head_branch_name
    slim :pull_perf
  end

  # pull eg perf
  get '/repos/:org/:repo/pulls/:id/eg-perf' do |org_name, repo_name, id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    eg_version = @pull.evergreen_version
    tasks = eg_version.builds.map { |build| build.tasks.first }
    @tasks = tasks.sort_by do |task|
      -task.time_taken
    end.map do |task|
      EvergreenTaskPresenter.new(task, @pull, eg_client, system)
    end
    @branch_name = @pull.head_branch_name
    slim :eg_perf
  end

  # pr log
  get '/repos/:org/:repo/pulls/:id/evergreen-log/:build_id' do |org_name, repo_name, pull_id, build_id|
    pull = gh_repo(org_name, repo_name).pull(pull_id)
    title = "#{repo_name}/#{pull_id} by #{pull.creator_name} [#{pull.head_branch_name}]"
    do_evergreen_log(build_id, title)
  end

  get '/repos/:org/:repo/pulls/:id/evergreen-log/:build_id/all' do |org_name, repo_name, pull_id, build_id|
    pull = gh_repo(org_name, repo_name).pull(pull_id)
    title = "All log: #{repo_name}/#{pull_id} by #{pull.creator_name} [#{pull.head_branch_name}]"
    do_evergreen_log(build_id, title, :all)
  end

  get '/repos/:org/:repo/pulls/:id/restart/:build_id' do |org_name, repo_name, pull_id, build_id|
    build = Evergreen::Build.new(eg_client, build_id)
    build.restart
    redirect "/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/restart-failed' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @statuses = @pull.statuses
    restarted = false

    @pull.travis_statuses.each do |status|
      if status.failed?
        status.restart
      end
      restarted = true
    end

    status = @pull.top_evergreen_status
    if status
      version_id = File.basename(status['target_url'])
      version = Evergreen::Version.new(eg_client, version_id)
      version.restart_failed_builds
      restarted = true
    end

    unless restarted
      return 'Could not find anything to restart'
    end

    redirect return_path || "/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/restart-all' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)

    status = @pull.top_evergreen_status
    if status
      version_id = File.basename(status['target_url'])
      version = Evergreen::Version.new(eg_client, version_id)
      version.restart_all_builds
      restarted = true
    end

    unless restarted
      return 'Could not find anything to restart'
    end

    redirect return_path || "/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/request-review' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @repo = system.hit_repo(org_name, repo_name)
    @pull.update(draft: false)
    @statuses = @pull.request_review('saghm', 'HanaPearlman', 'egiurleo')

    pull_p = PullPresenter.new(@pull, eg_client, system, @repo)
    jira_ticket = pull_p.jira_ticket_number
    if jira_ticket
      pr_url = "https://github.com/#{org_name}/#{repo_name}/pull/#{pull_id}"
      # https://developer.atlassian.com/server/jira/platform/jira-rest-api-for-remote-issue-links/
      payload = {
        globalId: "#{pull_p.jira_issue_key!}-pr-#{pull_id}",
        object: {
          url: pr_url,
          title: "Fix - PR ##{pull_id}",
          icon: {"url16x16":"https://github.com/favicon.ico"},
          status: {
            icon: {},
          },
        },
      }
      jirra_client.post_json("issue/#{pull_p.jira_issue_key!}/remotelink", payload)

      info = jirra_client.get_issue_fields(pull_p.jira_issue_key!)
      if info['issuetype']['name'] != 'Epic'
        begin
          jirra_client.transition_issue(pull_p.jira_issue_key!, 'In Code Review',
            assignee: {name: ENV['JIRA_USERNAME']})
        rescue Jirra::TransitionNotFound
          # ignore
        end
      end
    end

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/approve' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @pull.approve
    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/submit-patch' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.add_remote(@pull.head_owner_name, @pull.head_repo_name)
    diff = rc.diff_to_master(@pull.head_sha)
    repo = system.hit_repo(org_name, repo_name)
    rv = eg_client.create_patch(
      project_id: repo.evergreen_project_id,
      diff_text: diff,
      base_sha: rc.master_sha,
      description: "PR ##{pull_id}: #{@pull.title}",
      variant_ids: ['all'],
      task_ids: ['all'],
      finalize: true,
    )

    patch_id = rv['patch']['Id']

    patch = Patch.create!(
      id: patch_id,
      head_branch_name: @pull.head_branch_name,
      base_branch_name: @pull.base_branch_name,
      gh_pull_id: pull_id,
      eg_project_id: repo.evergreen_project_id,
      repo_id: repo.id,
      head_sha: @pull.head_sha,
      eg_submission_result: rv,
    )

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  # pull bump
  get '/repos/:org/:repo/pulls/:id/bump' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    version = Evergreen::Version.new(eg_client, @pull.evergreen_version_id)
    do_bump(version, params[:priority].to_i)
    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  # eg authorize pr
  get '/repos/:org/:repo/pulls/:id/authorize/:patch' do |org_name, repo_name, pull_id, patch_id|
    patch = Evergreen::Patch.new(eg_client, patch_id)
    patch.authorize!
    redirect return_path || "/repos/#{org_name}/#{repo_name}/pulls/#{pull_id}"
  end

  # aggregated results - mri
  get '/repos/:org/:repo/pulls/:id/mri-results' do |org_name, repo_name, pull_id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(pull_id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @pull.fetch_results(failed: params[:failed] == '1')
    @result = @pull.aggregate_result do |result|
      if params[:failed] == '1' && result.failed_results.count > 0
        !result.jruby?
      else
        false
      end
    end
    if @result.empty?
      if params[:failed]
        slim :no_failures
      else
        raise NotImplemented
      end
    else
      slim :results
    end
  end

  # aggregated results - jruby
  get '/repos/:org/:repo/pulls/:id/jruby-results' do |org_name, repo_name, pull_id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(pull_id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @pull.fetch_results
    @result = @pull.aggregate_result { |result| result.jruby? }
    slim :results
  end

  get '/repos/:org/:repo/pulls/:id/retitle-commit' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    subject, message = rc.commitish_message(@pull.head_sha)
    @pull.update(title: subject, body: message)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/retitle-jira' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    pull_p = PullPresenter.new(@pull, eg_client, system, @repo)

    subject = jirra_client.subject_for_issue(pull_p.jira_issue_key!)
    @pull.update(title: subject)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end
end
