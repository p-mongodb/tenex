module Github
  class Repo
    def initialize(client, owner_name, repo_name)
      @client = client
      @owner_name = owner_name
      @repo_name = repo_name
    end

    attr_reader :client, :owner_name, :repo_name

    def full_name
      "#{owner_name}/#{repo_name}"
    end

    def pulls(options={})
      pulls = []
      each_pull(options) do |pull|
        pulls << pull
      end
      pulls
    end

    def pull(pull_id)
      info = client.get_json("repos/#{full_name}/pulls/#{pull_id}")
      Pull.new(client, full_name, info: info)
    end

    def each_pull(options={})
      url = "repos/#{full_name}/pulls?"
      if options[:state]
        url += "state=#{options[:state]}&"
      end
      client.paginated_get(url) do |info|
        pull = Pull.new(client, full_name, info: info)
        # github's filtering options are nonexistent
        if creator = options[:creator]
          if pull.creator_name != creator
            pull = nil
          end
        end
        if pull
          yield pull
        end
      end
    end
  end
end
