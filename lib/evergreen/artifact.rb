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

    def extract_tarball(&block)
      if client.cache_root
        extract_tarball_with_cache(&block)
      else
        extract_tarball_without_cache do |path|
          yield path
        end
      end
    end

    def cache_basename
      Digest::SHA1.new.update(url).hexdigest
    end

    def cache_path
      File.join(client.cache_root, cache_basename).sub(/\.tar\.gz$/, '')
    end

    def extract_tarball_with_cache(&block)
      cache_path = self.cache_path
      if File.exist?(cache_path)
        yield cache_path
      else
        extract_tarball_without_cache(&block)
      end
    end

    def extract_tarball_without_cache
      cache_path = self.cache_path
      path = cache_path + '.part'
      FileUtils.rm_rf(path)
      FileUtils.mkdir_p(path)
      begin
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
      rescue
        FileUtils.rm_rf(path)
        raise
      end
      FileUtils.mv(path, cache_path)

      yield cache_path
    end

    def extract_tarball_path(rel_path)
      extract_tarball do |root|
        Find.find(root) do |path|
          this_rel_path = path[root.length+1...path.length]
          if rel_path == this_rel_path
            return File.read(path)
          end
        end
      end
      nil
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

    def tarball_file_infos
      [].tap do |infos|
        extract_tarball do |root|
          Find.find(root) do |path|
            next unless File.file?(path)
            rel = path[root.length+1...path.length]
            if rel
              infos << ArtifactFileInfo.new(rel, path)
            end
          end
        end
      end
    end
  end
end
