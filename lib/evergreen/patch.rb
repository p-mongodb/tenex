module Evergreen
  class Patch
    def initialize(client, id, info: nil)
      @client = client
      @id = id
      @info = info
    end

    attr_reader :client, :id, :info

    def status
      info['status']
    end

    def description
      if info['description'] && !info['description'].empty?
        info['description']
      else
        "Patch #{info['patch_number']} by #{info['author']}"
      end
    end

    def version_id
      version_id = info['version']
      if version_id == ''
        version_id = nil
      end
      version_id
    end

    def version
      if version_id.nil?
        raise ArgumentError, "Cannot obtain version when version_id is nil (for patch #{id})"
      end
      client.version_by_id(version_id)
    end

    # Heuristic method to determine the likely PR number using the description,
    # assuming the standard generated description.
    def pr_number
      if info['description'] && info['description'] =~ /\A'([^']+?)' pull request #(\d+) by/
        $2.to_i
      else
        nil
      end
    end

    # Heuristic method to determine the likely GH repo using the description,
    # assuming the standard generated description.
    def repo_full_name
      if info['description'] && info['description'] =~ /\A'([^']+?)' pull request #(\d+) by/
        $1
      else
        nil
      end
    end

=begin What is in info['builds']?
    def builds
      info['builds'].map do |build_id|
        Build.new(client, build_id)
      end
    end
=end

    def finished?
      !%w(created started).include?(status)
    end

    def authorize!
      client.patch_json("patches/#{id}", activated: true)
    end
  end
end
