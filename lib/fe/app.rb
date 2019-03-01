require 'multi_concern'
autoload :JIRA, 'jira-ruby'
autoload :Nokogiri, 'nokogiri'
require 'open-uri'
autoload :Ansi, 'ansi/to/html'
require 'forwardable'
require 'evergreen'
require 'github'
require 'faraday'
require 'faraday/detailed_logger'
require 'slim'
require 'sinatra'
require 'sinatra/reloader'
require 'travis'
require 'taw'
autoload :Jirra, 'jirra/client'

Dir[File.join(File.dirname(__FILE__), 'presenters', '*.rb')].each do |path|
  require 'fe/'+path[File.dirname(__FILE__).length+1...path.length].sub(/\.rb$/, '')
end

Travis.access_token = ENV['TRAVIS_TOKEN']

Slim::Engine.set_options pretty: true, sort_attrs: false

ARTIFACTS_LOCAL_PATH = Pathname.new(__FILE__).dirname.join('../../.artifacts')
FileUtils.mkdir_p(ARTIFACTS_LOCAL_PATH)

class App < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'public')
  set :strict_paths, false

  def gh_client
    @gh_client ||= Github::Client.new(
        username: ENV['GITHUB_USERNAME'],
        auth_token: ENV['GITHUB_TOKEN'],
      )
  end

  def gh_repo(org_name, repo_name)
    gh_client.repo(org_name, repo_name)
  end

  def eg_client
    @eg_client ||= Evergreen::Client.new(
        username: ENV['EVERGREEN_AUTH_USERNAME'],
        api_key: ENV['EVERGREEN_API_KEY'],
      )
  end

  def system
    System.new(eg_client, gh_client)
  end

  private def do_evergreen_log(build_id, title)
    build = Evergreen::Build.new(eg_client, build_id)
    do_log(build.task_log, build.task_log_url, title)
  end

  private def do_log(log, log_url, title)
    log = log.gsub(%r,<i class="fa fa-link line-link" id='line-link-\d+'></i> ,, '')
    lines = log.split("\n")
    lines.each_with_index do |line, index|
      if line =~ %r,Failure/Error:,
        insert_point = [index-3, 0].max
        lines.insert(insert_point, '<a name="first-failure"></a>')
        log = lines.join("\n")
        break
      end
    end
    style = %q,
      pre { overflow: initial; }
    ,
    log.sub!(/<\/head>/, "<style>#{style}</style><title>#{title}</title></head>")
    inject = %Q,<p style='margin:1em;font-size:150%'><a href="#{log_url}">Log @ Evergreen</a></p>,
    log.sub!(/<body(.*?)>/, "<body\\1>#{inject}")
    log
  end

  private def do_bump(version, priority)
    if priority == 0
      raise "Bumping to 0?"
    end
    version.builds.each do |build|
      build.tasks.each do |task|
        unless task.completed?
          task.set_priority(priority)
        end
      end
    end
  end

  private def return_path
    URI.parse(request.env['HTTP_REFERER']).path
  end

  private def distros_with_cache
    cache_state = CacheState.first || CacheState.new
    if cache_state.distros_ok?
      distros = Distro.order(name: 1)
      distros.map do |distro|
        Evergreen::Distro.new(eg_client, distro.name, info: {'name' => distro.name})
      end
    else
      distros = eg_client.distros
      Distro.delete_all
      distros.each do |distro|
        Distro.create!(name: distro.name)
      end
      cache_state.distros_updated_at = Time.now
      cache_state.save!
      distros
    end
  end

  private def keys_with_cache
    cache_state = CacheState.first || CacheState.new
    if cache_state.keys_ok?
      keys = Key.order(name: 1)
      keys.map do |key|
        Evergreen::Key.new(eg_client, key.name, info: {'name' => key.name})
      end
    else
      keys = eg_client.keys
      Key.delete_all
      keys.each do |key|
        Key.create!(name: key.name)
      end
      cache_state.keys_updated_at = Time.now
      cache_state.save!
      keys
    end
  end

  private def jira_client
    @jira_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
        :context_path => '',
        :auth_type    => :basic
      }

      JIRA::Client.new(options)
    end
  end

  private def jirra_client
    @jirra_client ||= begin
      options = {
        :username     => ENV['JIRA_USERNAME'],
        :password     => ENV['JIRA_PASSWORD'],
        :site         => ENV['JIRA_SITE'],
      }

      ::Jirra::Client.new(options)
    end
  end
end

module Routes
  extend MultiConcern
end

require 'fe/routes/pull'
require 'fe/routes/eg'
require 'fe/routes/spawn'
require 'fe/routes/travis'
require 'fe/routes/jira'
require 'fe/routes/global'

class App
  include Routes
end
