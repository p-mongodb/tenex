require 'forwardable'

module Github
  class Pull
    extend Forwardable

    def initialize(client, repo_full_name, info: nil)
      @client = client
      @repo_full_name = repo_full_name
      @info = info
    end

    attr_reader :client, :repo_full_name, :info

    def_delegators :@info, :[], :[]=

    def number
      info['number']
    end

    def head_sha
      info['head']['sha']
    end

    def head_label
      info['head']['label']
    end

    # Who opened the PR (could be different from author of PR's head)
    def creator_name
      info['user']['login']
    end

    def request_review(*reviewers)
      client.post_json("/repos/#{repo_full_name}/pulls/#{info['number']}/requested_reviewers",
        {reviewers: reviewers})
    end

    def statuses
      @statuses ||= begin
        payload = client.paginated_get("/repos/#{repo_full_name}/statuses/#{head_sha}?per_page=100")

        # sometimes the statuses are duplicated?
        payload.delete_if do |status|
          payload.any? do |other_status|
            other_status['context'] == status['context'] &&
            other_status['id'] != status['id'] &&
            other_status['updated_at'] > status['updated_at']
          end
        end
        payload.sort_by! { |a| a['context'] }

        payload.map do |info|
          Status.new(client, info: info)
        end
      end
    end

    def number
      info['number']
    end

    def head_branch_name
      info['head']['ref']
    end

    def head_owner_name
      if info['head']['repo']
        info['head']['repo']['owner']['login']
      else
        nil
      end
    end

    def head_repo_name
      if info['head']['repo']
        info['head']['repo']['name']
      else
        nil
      end
    end

    def base_owner_name
      if info['base']['repo']
        info['base']['repo']['owner']['login']
      else
        nil
      end
    end

    def base_branch_name
      info['base']['ref']
    end

    def status_by_name(name)
      statuses.select do |status|
        status['context'] == name
      end.last
      # there can be more than one
    end

    def top_evergreen_status
      status_by_name('evergreen')
    end

    def evergreen_version_id
      status = top_evergreen_status
      if status
        if status['target_url'] =~ %r,version/([\da-fA-F]+),
          return $1
        end
      end
      nil
    end

    def top_travis_status
      status_by_name('continuous-integration/travis-ci/pr')
    end

    def travis_statuses
      @travis_statuses ||= begin
        top_status = top_travis_status
        return [] unless top_status

        if top_status['target_url'] =~ %r,builds/(\d+),
          build = Travis::Build.find($1)
          build.jobs.map do |job|
            TravisStatus.new(job)
          end
        else
          []
        end
      end
    end

    def jira_project
      case repo_full_name
      when 'mongodb/mongoid'
        'mongoid'
      when 'mongodb/mongo-ruby-driver'
        'ruby'
      else
        raise "Bogus repo name: #{repo_full_name}"
      end
    end

    def jira_ticket_number
      number = nil
      sources = [info['body']] + comments.map(&:body)
      sources.each do |body|
        if body =~ /#{jira_project}-(\d+)/i
          if number
            raise "Confusing ticket situation"
          end
          number = $1.to_i
        end
      end
      if number.nil?
        if info['head']['ref'].to_i.to_s == info['head']['ref']
          number = info['head']['ref'].to_i
        end
      end
      number
    end

    def jira_ticket!
      number = jira_ticket_number
      if number.nil?
        raise "Could not figure out jira ticket number"
      end
      "#{jira_project.upcase}-#{number}"
    end

    class TravisStatus
      extend Forwardable

      def initialize(info)
        @info = info
      end

      attr_reader :info

      def_delegators :info, :failed?, :restart, :state

      def context
        "Ruby: #{info.config['rvm']} #{info.config['env']}"
      end

      def target_url
        "https://travis-ci.org/#{info.repository.owner_name}/#{info.repository.name}/jobs/#{info.id}"
      end

      def raw_log_url
        "https://api.travis-ci.org/v3/job/#{info.id}/log.txt"
      end

      def html_log_url
        "/travis/log/#{info.id}"
      end

      def restart_url
        "/repos/#{info.repository.owner_name}/#{info.repository.name}/restart-travis/#{info.id}"
      end
    end

    def approved?
      !raw_reviews.empty? &&
      raw_reviews.all? do |info|
        info['state'].downcase == 'approved'
      end &&
      raw_requested_reviewers['users'].empty?
    end

    def review_requested?
      !raw_requested_reviewers['users'].empty?
    end

    private def raw_reviews
      @raw_reviews ||=
        client.get_json("repos/#{repo_full_name}/pulls/#{number}/reviews")
    end

    private def raw_requested_reviewers
      @raw_requested_reviewers ||=
        client.get_json("repos/#{repo_full_name}/pulls/#{number}/requested_reviewers")
    end

    def update(attrs)
      client.request_json(:patch, "repos/#{repo_full_name}/pulls/#{number}", attrs)
    end

    def comments
      @comments ||= client.get_json(info['comments_url']).map do |info|
        Comment.new(client, info: info)
      end
    end
  end
end
