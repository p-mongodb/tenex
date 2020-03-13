require 'fe/globals'
require 'fe/artifact_cache'
require 'sidekiq'

class ResultFetcher
  include Sidekiq::Worker
  include Globals

  def do_perform
    Project.where(workflow: true).each do |project|
      puts "fetching for #{project.slug}"
      repo = project.repo
      gh_pulls = gh_repo(repo.owner_name, repo.repo_name).pulls
      gh_pulls.each do |gh_pull|
        eg_version_id = gh_pull.evergreen_version_id
        next unless eg_version_id
        eg_version = Evergreen::Version.new(eg_client, eg_version_id)
        eg_version.builds.each do |build|
          if build.artifact?('rspec.json')
            # TODO update for rspec.json.gz
            artifact = build.artifact('rspec.json')
            begin
              ArtifactCache.instance.fetch_artifact(artifact.url)
            rescue => e
              puts "Failed to fetch #{artifact.url}: #{e.class}: #{e}"
            end
          end
        end
      end
    end
  end

  def perform
    do_perform
  rescue => e
    puts "#{e.class}: #{e}"
    puts e.backtrace.join("\n")
    raise
  end
end
