require 'pathname'

class System
  EVERGREEN_BINARY_URL = 'https://evergreen.mongodb.com/clients/linux_amd64/evergreen'
  TMP_DIR = Pathname.new(File.join(File.dirname(__FILE__), '../../tmp'))

  def initialize(eg_client, gh_client)
    @eg_client, @gh_client = eg_client, gh_client
  end

  attr_reader :eg_client, :gh_client

  def newest_evergreen_version(version)
    return nil unless version
    project = evergreen_project_for_github_repo(
      version.pr_info[:owner_name], version.pr_info[:repo_name])
    # Sometimes the version appears to not be in the recent patch list
    project.recent_patches.detect do |patch|
      patch.description == version.message
    end
  end

  def evergreen_project_for_github_repo(owner_name, repo_name)
    repo = Repo.find_or_create_by(owner_name: owner_name, repo_name: repo_name)
    if repo.evergreen_project_id.nil? && !repo.evergreen_project_queried_at?
      project = eg_client.project_for_github_repo(owner_name, repo_name)
      if project
        repo.evergreen_project_id = project.id
      end
      repo.evergreen_project_queried_at = Time.now
      repo.save!
    end
    Evergreen::Project.new(eg_client, repo.evergreen_project_id)
  end

  def evergreen_project_for_github_repo!(owner_name, repo_name)
    evergreen_project_for_github_repo(owner_name, repo_name).tap do |p|
      raise "No project for #{owner_name}/#{repo_name}" unless p
    end
  end

  def hit_repo(owner_name, repo_name)
    repo = Repo.find_or_create_by(owner_name: owner_name, repo_name: repo_name)
    RepoHit.create!(repo: repo)
    repo.hit_count = RepoHit.where(repo: repo).count
    repo.save!
    repo
  end

  def evergreen_binary_path
    @evergreen_binary_path ||= begin
      found_path = nil
      ENV['PATH'].split(':').each do |dir|
        if File.executable?(path = File.join(dir, 'evergreen'))
          found_path = path
          break
        end
      end
      if found_path.nil? && File.exist?(local_evergreen_binary_path)
        found_path = local_evergreen_binary_path
      end
      found_path
    end
  end

  def local_evergreen_binary_path
    TMP_DIR.join('bin/evergreen')
  end

  def fetch_evergreen_binary_if_needed
    if evergreen_binary_path.nil?
      FileUtils.mkdir_p(File.dirname(local_evergreen_binary_path))
      contents = open(EVERGREEN_BINARY_URL).read
      File.open(local_evergreen_binary_path + '.part', 'w') do |f|
        f << contents
      end
      FileUtils.mv(local_evergreen_binary_path + '.part', local_evergreen_binary_path)
    end
  end

  def evergreen_global_config_path
    TMP_DIR.join('evergreen.yml')
  end

  def create_global_evergreen_config_if_needed
    unless File.exists?(evergreen_global_config_path)
      config = {
        'api_server_host' => 'https://evergreen.mongodb.com/api',
        'ui_server_host' => 'https://evergreen.mongodb.com',
        'api_key' => ENV['EVERGREEN_API_KEY'],
        'user' => ENV['EVERGREEN_AUTH_USERNAME'],
      }
      FileUtils.mkdir_p(File.dirname(evergreen_global_config_path))
      File.open("#{evergreen_global_config_path}.part", 'w') do |f|
        f << YAML.dump(config)
      end
      FileUtils.mv("#{evergreen_global_config_path}.part", evergreen_global_config_path)
    end
  end
end
