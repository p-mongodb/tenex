module Jirra
  class Version
    def initialize(info:)
      @info = info
    end

    attr_reader :info

    def name
      info['name']
    end

    def gem_version
      Gem::Version.new(name)
    end

    def id
      info['id']
    end

    def archived?
      info['archived']
    end

    def released?
      info['released']
    end

    def release_date
      if date = info['releaseDate']
        Date.parse(date)
      else
        nil
      end
    end

    def project_id
      info['project_id']
    end
  end
end
