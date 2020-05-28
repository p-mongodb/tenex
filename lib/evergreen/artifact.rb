autoload :IceNine, 'ice_nine'
module Gem
  autoload :Package, 'rubygems/package'
end

module Evergreen
  class Artifact
    def initialize(client, info:, task:)
      @client = client
      @info = IceNine.deep_freeze(info)
      @task = task
    end

    attr_reader :client, :info

    # An artifact does not record which execution of a task it is associated
    # with. It is possible to deduce task id from artifact url, but it is
    # dangerous to simply query a task by this id because the task's
    # execution may be a different one than the one which created the artifact
    # (e.g. the task may be in progress which doesn't make sense since the
    # task must have finished to produce the artifact).
    # The task referenced here is always written into the artifact during
    # the artifact's construction, when the artifact is retrieved for a
    # particular (execution of a) task.
    attr_reader :task

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
      parts = [client.cache_root, 'artifacts']
      if task
        if task.started_at
          parts << task.started_at.to_i.to_s
        end
      end
      parts << cache_basename
      File.join(parts)
    end

    def size
      if client.cache_root && File.exist?(cache_path)
        File.size(cache_path)
      else
        resp = client.request(:head, url)
        unless resp.status == 200
          raise "Failed to HEAD #{url}"
        end
        unless cl = resp.headers['content-length']
          raise "Missing content-length for #{url}"
        end
        cl.to_i
      end
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

    def tarball_entry(full_name, &block)
      yield_tarball do |tar|
        tar.seek(full_name, &block)
      end
    end

    def tarball_file_infos
      [].tap do |infos|
        tarball_each do |entry|
          infos << ArtifactFileInfo.new(entry.full_name, size: entry.size)
        end
      end
    end

    def tarball_each(&block)
      yield_tarball do |tar|
        tar.each(&block)
      end
    end

    private

    def yield_tarball
      fetch_into_cache

      if File.size(cache_path) == 0
        raise "Tarball is zero length - this is not good"
      end

      rv = nil
      Zlib::GzipReader.open(cache_path) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          rv = yield tar
        end
      end
      rv
    end

    def fetch_into_cache
      if client.cache_root && File.exist?(cache_path)
        return
      end

      FileUtils.mkdir_p(File.dirname(cache_path))
      File.open(cache_path + '.part', 'w') do |f|
        stream = URI.open(url)
        begin
          while chunk = stream.read(1048576)
            f.write(chunk)
          end
        ensure
          stream.close
        end
      end

      FileUtils.mv(cache_path + '.part', cache_path)
    end
  end
end
