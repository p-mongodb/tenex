autoload :Orchestrator, 'fe/orchestrator'

Routes.included do

  # pull
  get '/repos/:org/:repo/pulls/:id' do |org_name, repo_name, id|
    @repo = system.hit_repo(org_name, repo_name)
    pull = gh_repo(org_name, repo_name).pull(id)
    @pull = PullPresenter.new(pull, eg_client, system, @repo)
    @statuses = pull.statuses

    #@pull.fetch_results
    #@pull.aggregate_result

    @configs = {
      'mongodb-version' => %w(4.4 4.2 4.0 3.6 3.4 3.2 3.0 2.6 latest krb),
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
        if label =~ /kerberos-tests|test-kerberos|kerberos-unit/
          #meta['kerberos'] = true
          meta['auth-and-ssl'] = 'krb-unit'
        elsif label =~ /kerberos-integration-(.*)/
          meta['mongodb-version'] = 'krb'
          meta['topology'] = $1
          meta['auth-and-ssl'] = 'krb-integration'
        elsif label =~ /enterprise-auth-tests-ubuntu/
          meta['mongodb-version'] = 'krb'
          meta['topology'] = 'ubuntu'
          meta['auth-and-ssl'] = 'krb-integration'
        elsif label =~ /enterprise-auth-tests-rhel/
          meta['mongodb-version'] = 'krb'
          meta['topology'] = 'rhel'
          meta['auth-and-ssl'] = 'krb-integration'
        elsif label =~ /local-tls/
          #meta['mongodb-version'] = meta['mongodb-version']
          meta['auth-and-ssl'] = 'TLS-verify'
        elsif label =~ /x509-tests/
          #meta['mongodb-version'] = meta['mongodb-version']
          meta['auth-and-ssl'] = 'x509'
        else
          meta['auth-and-ssl'] ||= 'noauth-and-nossl'
        end
        @table_keys.each do |key|
          value = meta[key]
          if value.nil?
            raise "Nil value for #{key} in #{status.status.context}"
            #next
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
        if meta_for_label.delete('fle')
          short_label << 'E'
        end
        if meta_for_label.delete('kerberos')
          short_label << 'K'
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
        case bson = meta_for_label.delete('bson')
        when 'master'
          short_label << 'BM'
        when 'min'
          short_label << 'Bm'
        when nil
        else
          meta_for_label['bson'] = bson
        end
        if compressor = meta_for_label.delete('compressor')
          short_label << compressor[0].upcase
        end
        # We do not currently run the same test on multiple OSes
        meta_for_label.delete('os')
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
          raise "overwrite for #{id}: #{short_label} #{meta.inspect}"
          #map["x-#{short_label}"] = status
          @untaken_statuses << status
        else
          map[short_label] = status
        end
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
      if @category_values['mongodb-version']
        @category_values['mongodb-version'] = @configs['mongodb-version'].select do |v|
          @category_values['mongodb-version'].include?(v)
        end
      end
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
    @owner_name = org_name
    @repo_name = repo_name
    @pull_id = pull_id
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
    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
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
      version_id = File.basename(status['target_url']).sub(/\?.*/, '')
      version = Evergreen::Version.new(eg_client, version_id)
      version.restart_failed_builds
      restarted = true
    end

    unless restarted
      return 'Could not find anything to restart'
    end

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
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

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/request-review' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @repo = system.hit_repo(org_name, repo_name)
    @pull.update(draft: false)
    @statuses = @pull.request_review(*ENV['PR_REVIEWERS'].split(','))

    pull_p = PullPresenter.new(@pull, eg_client, system, @repo)
    jira_ticket = pull_p.jira_ticket_number
    if jira_ticket
      orchestrator = Orchestrator.new
      orchestrator.link_pr_in_issue(org_name: org_name, repo_name: repo_name,
        pr_num: pull_id, jira_issue_key: pull_p.jira_issue_key!,
        pr_title: @pull.title)

      orchestrator.transition_issue_to_in_review(pull_p.jira_issue_key!)
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
    eg_patch = eg_client.create_patch(
      project_id: repo.evergreen_project_id,
      diff_text: diff,
      base_sha: rc.master_sha,
      description: "PR ##{pull_id}: #{@pull.title}",
      variant_ids: ['all'],
      task_ids: ['all'],
      finalize: true,
    )

    patch_id = eg_patch.id

    patch = Patch.create!(
      id: patch_id,
      head_branch_name: @pull.head_branch_name,
      base_branch_name: @pull.base_branch_name,
      gh_pull_id: pull_id,
      eg_project_id: repo.evergreen_project_id,
      repo_id: repo.id,
      head_sha: @pull.head_sha,
      eg_submission_result: eg_patch.info,
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
      @filtered = true
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
    @filtered = true
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

    Orchestrator.new.link_issue_in_pr(pull: @pull)

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/eg-validate' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)

    system.create_global_evergreen_config_if_needed

    eg_path = system.evergreen_binary_path
    unless eg_path
      raise 'No evergreen binary path'
    end

    rc = RepoCache.new(@pull.base_owner_name, @pull.head_repo_name)
    rc.update_cache
    rc.add_remote(@pull.head_owner_name, @pull.head_repo_name)
    rc.checkout("#{@pull.head_owner_name}/#{@pull.head_branch_name}")

    summaries = {}

    paths = Dir[rc.cached_repo_path.join('.evergreen', '*.yml')]
    paths += Dir[rc.cached_repo_path.join('.evergreen', '.*.yml')]
    paths.sort.each do |project_eg_config_path = rc.cached_repo_path|
      summary = OpenStruct.new(status: 'ok')

      contents = File.read(project_eg_config_path)

      # Validate evergreen configuration internally since the evergreen tool
      # provides wrong line numbers (https://jira.mongodb.org/browse/EVG-6413)
      # and its error messages are often cryptic and do not clearly indicate
      # what the problem is/how to fix it.
      begin
        Evergreen::ParserValidator.new(contents).validate!
      rescue Evergreen::ProjectFileInvalid => e
        summary.status = 'failed'
        summary.ruby_error = e.to_s
      end

      cmd = [eg_path, '-c', system.evergreen_global_config_path.to_s,
        'validate', project_eg_config_path.to_s]
      proc, output = ChildProcessHelper.get_output(cmd)
      if proc.exit_code != 0
        summary.status = 'failed'
        if output.empty?
          summary.evergreen_error = "Process exited with code #{proc.exit_code} but produced no output"
        else
          summary.evergreen_error = "#{output}\nProcess exited with code #{proc.exit_code}"
        end
      elsif output == ''
        summary.status = 'failed'
        summary.evergreen_error = "Evergreen tool validation produced no output (but exited successfully). This generally indicates a bug in the tool (EVG-6417)."
      end

      summaries[File.basename(project_eg_config_path)] = summary
    end

    @summaries = summaries
    @eg_binary_mtime = File.stat(eg_path).mtime
    slim :eg_validate
  end

  get '/repos/:org/:repo/pulls/:id/edit-pr' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @return_path = return_path
    slim :edit_pr
  end

  post '/repos/:org/:repo/pulls/:id/edit-pr' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    title = params[:title]
    body = params[:body]
    @pull.update(title: title, body: body)
    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end

  get '/repos/:org/:repo/pulls/:id/in-progress' do |org_name, repo_name, pull_id|
    @pull = gh_repo(org_name, repo_name).pull(pull_id)
    @repo = system.hit_repo(org_name, repo_name)

    pull_p = PullPresenter.new(@pull, eg_client, system, @repo)
    jira_ticket = pull_p.jira_ticket_number
    if jira_ticket
      orchestrator = Orchestrator.new
      orchestrator.link_pr_in_issue(org_name: org_name, repo_name: repo_name,
        pr_num: pull_id, jira_issue_key: pull_p.jira_issue_key!,
        pr_title: @pull.title)

      orchestrator.transition_issue_to_in_progress(pull_p.jira_issue_key!)
    end

    redirect return_path || "/repos/#{@pull.repo_full_name}/pulls/#{pull_id}"
  end
end
