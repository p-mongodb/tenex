require 'forwardable'
require "link_header"

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

    def head_sha
      info['head']['sha']
    end

    def request_review(*reviewers)
      r = client.connection.post("/repos/#{repo_full_name}/pulls/#{info['number']}/requested_reviewers",
        body: JSON.generate(reviewers))
      if r.status != 200
        raise "Review request failed: #{r.body}"
      end
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

    def success_count
      @success_count ||= statuses.inject(0) do |sum, status|
        sum + (status['state'] == 'success' ? 1 : 0)
      end
    end

    def failure_count
      @failure_count ||= statuses.inject(0) do |sum, status|
        sum + (status['state'] == 'failure' ? 1 : 0)
      end
    end

    def pending_count
      @pending_count ||= statuses.inject(0) do |sum, status|
        sum + (%w(success failure).include?(status['state']) ? 0 : 1)
      end
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

      def log_url
        "https://api.travis-ci.org/v3/job/#{info.id}/log.txt"
      end

      def restart_url
        "/repos/#{info.repository.owner_name}/#{info.repository.name}/restart-travis/#{info.id}"
      end
    end
  end
end
