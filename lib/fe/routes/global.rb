Routes.included do

  get '/' do
    slim :landing
  end

  get '/ruby-toolchain-urls' do
    toolchain = Toolchain.new
    toolchain_sha = toolchain.latest_sha
    project = Evergreen::Project.new(eg_client, 'mongo-ruby-driver-toolchain')
    eg_version = project.recent_versions.detect do |version|
      version.revision == toolchain_sha
    end
    @builds = eg_version.builds
    @urls = @builds.map do |build|
      log = build.tasks.first.task_log
      if log =~ %r,Putting mongo-ruby-toolchain/ruby-toolchain.tar.gz into (https://.*),
        $1
      else
        nil
      end
    end
    slim :ruby_toolchain_urls
  end

  get '/workflow' do
    @repos = Repo.where(workflow: true).sort_by(&:full_name)
    slim :workflow
  end
end
