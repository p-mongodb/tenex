require 'singleton'

class ArtifactCache
  include Singleton

  # Fetches the artifact at +url+ and stores it locally. Skips the fetch if
  # fetched already. Returns full local path to the fetched artifact.
  def fetch_artifact(url)
    basename = File.basename(url)
    local_path = ARTIFACTS_LOCAL_PATH.join(basename)
    unless File.exist?(local_path)
      puts "Fetching #{url}"
      content = open(url).read
      File.open(local_path.to_s + '.tmp', 'w') do |f|
        f << content
      end
      FileUtils.mv(local_path.to_s + '.tmp', local_path)
    end
    local_path
  end
end
