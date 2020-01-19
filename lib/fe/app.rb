require 'fe/env'
require 'multi_concern'
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
require 'action_view/helpers/number_helper'
require 'fe/globals'
require 'fe/config'
require 'fe/formatting_helpers'
require 'fe/evergreen_cache'

Dir[File.join(File.dirname(__FILE__), 'presenters', '*.rb')].each do |path|
  require 'fe/'+path[File.dirname(__FILE__).length+1...path.length].sub(/\.rb$/, '')
end

Travis.access_token = ENV['TRAVIS_TOKEN']

Slim::Engine.set_options pretty: true, sort_attrs: false

FileUtils.mkdir_p(ARTIFACTS_LOCAL_PATH)

class App < Sinatra::Base
  include Globals
  include Env::Access
  include ActionView::Helpers::NumberHelper
  include FormattingHelpers

  configure :development do
    register Sinatra::Reloader
  end

  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'public')
  set :strict_paths, false
  # Show exceptions in production environment
  set :show_exceptions, true

  def project_by_slug(slug)
    project = Project.where(slug: slug).first
    if project.nil?
      raise "Project not found for #{slug}"
    end
    project
  end

  private def do_evergreen_log(build_id, title, which = :task)
    unless %i(task all).include?(which)
      raise ArgumentError, "Invalid which value #{which}"
    end
    build = Evergreen::Build.new(eg_client, build_id)
    cached_build, log_lines, log_url = EvergreenCache.build_log(build, which)

    @title = title
    @log_lines = log_lines
    @eg_log_url = log_url
    @cached_build = cached_build
    slim :eg_log
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
    if params[:return_path]
      params[:return_path]
    elsif request.env['HTTP_REFERER']
      URI.parse(request.env['HTTP_REFERER']).path
    end
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
require 'fe/routes/paste'
require 'fe/routes/commits'
require 'fe/routes/gh'
require 'fe/routes/project'
require 'fe/routes/wiki'

class App
  include Routes
end
