module Evergreen
  class Artifact
    def initialize(client, info:)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(name url visibility ignore_for_fetch).each do |m|
      define_method(m) do
        info[m]
      end
    end

    def extract_tarball
      Dir.mktmpdir do |path|
        process = ChildProcess.build('tar', 'zxf', '-', '-C', path)
        process.duplex = true
        process.start
        begin
          f = open(url)
          begin
            while content = f.read(1048576)
              process.io.stdin.write(content)
            end
          ensure
            f.close
          end
        ensure
          process.io.stdin.close
          process.wait
        end

        unless process.exit_code == 0
          raise "Failed to fetch/untar"
        end

        yield path
      end
    end

    def extract_tarball_file(basename)
      extract_tarball do |root|
        Find.find(root) do |path|
          if File.basename(path) == basename
            return File.read(path)
          end
        end
      end
      nil
    end
  end
end
