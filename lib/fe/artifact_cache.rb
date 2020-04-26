require 'fe/config'
require 'open-uri'
require 'singleton'
autoload :Zlib, 'zlib'
autoload :FileUtils, 'fileutils'
autoload :Utils, 'fe/utils'

class ArtifactCache
  include Singleton

  # Fetches the artifact at +url+ and stores it locally. Skips the fetch if
  # fetched already. Returns full local path to the fetched artifact.
  def fetch_artifact(url)
    basename = File.basename(url)
    if basename.length > 250
      ext = basename.split('.').last
      basename = Digest::MD5.new.update(basename).hexdigest + '.' + ext
    end
    local_path = ARTIFACTS_LOCAL_PATH.join(basename).to_s
    unless File.exist?(local_path)
      puts "Fetching #{url}"
      content = open(url).read
      File.open(local_path + '.tmp', 'w') do |f|
        f << content
      end
      FileUtils.mv(local_path + '.tmp', local_path)
    end
    local_path
  end

  # Fetches the artifact at +url+ and stores it locally. Skips the fetch if
  # fetched already. Returns full local path to the fetched artifact.
  # If url does not end in .gz, this method compresses the contents at the
  # URL with gzip and stores it in compressed form.
  def fetch_compressed_artifact(url, subdir:)
    basename = File.basename(url)
    if basename =~ /((?:\.\w{1,4})+)$/
      ext = $1
    else
      ext = nil
    end
    if basename.length > 200
      basename = Utils.md5(basename)
      if ext
        basename += '.' + ext
      end
    end
    FileUtils.mkdir_p(ARTIFACTS_LOCAL_PATH.join(subdir))
    local_path = ARTIFACTS_LOCAL_PATH.join(subdir, basename).to_s
    if ext.end_with?('.gz')
      compress = false
    else
      compress = true
      local_path += '.gz'
    end
    unless File.exist?(local_path)
      puts "Fetching #{url}"
      content = open(url).read
      tmp_path = local_path + '.tmp'
      if compress
        Zlib::GzipWriter.open(tmp_path) do |gz|
          gz << content
        end
      else
        File.open(tmp_path, 'w') do |f|
          f << content
        end
      end
      FileUtils.mv(local_path + '.tmp', local_path)
    end
    local_path
  end

  def read_compressed_artifact(path)
    Zlib::GzipReader.open(path) do |gz|
      gz.read
    end
  end
end
