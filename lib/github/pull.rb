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

    def_delegator :@info, :[]

    def head_sha
      info['head']['sha']
    end

    def statuses
      payload = client.get_json("/repos/#{repo_full_name}/statuses/#{head_sha}?per_page=100")

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
end
