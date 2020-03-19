require 'fe/env'
require 'multi_concern'
autoload :Nokogiri, 'nokogiri'
require 'open-uri'
autoload :Ansi, 'ansi/to/html'
require 'forwardable'
require 'evergreen'
require 'github'
require 'fe/pull_ext'
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

%w(models presenters).each do |subdir|
  Dir[File.join(File.dirname(__FILE__), subdir, '*.rb')].each do |path|
    require 'fe/'+path[File.dirname(__FILE__).length+1...path.length].sub(/\.rb$/, '')
  end
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
    set_local_test_command(log_lines)

    @title = title
    @log_lines = log_lines
    @eg_log_url = log_url
    @cached_build = cached_build
    @project_id = build.project_id
    @version_id = build.version_id
    slim :eg_log
  end

  private def do_simple_evergreen_log(log, log_url, title)
    num = 0
    log_lines = log.split("\n").map do |line|
      {num: num += 1, severity: 'info', text: line, html: line}
    end
    set_local_test_command(log_lines)
    @title = title
    @log_lines = log_lines
    @eg_log_url = log_url
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

  private

  def set_local_test_command(log_lines, result: nil)
    log_lines.each_with_index do |line, index|
      if line[:text] =~ /To test this configuration locally:/
        loop do
          index += 1
          text = text = log_lines[index][:text]
          if text =~ /test-on-docker/ && text !~ /\+ echo/
            # The [P: 40] prefix is "log message priority".
            # When added it is simply a duplicate of severity with the
            # severities mapped to various integer values
            # (30, 40 and 70 for debug, info and error).
            # There may be other priorities added later and they could
            # conceivably be useful, but for the purposes of test command
            # extraction they can be ignored.
            # The second bracketed bit is the timestamp.
            @local_test_command = text.sub(/^(\[P: \d+\] )?\[[^\]]+\] /, '')

            if result
              failed_file_paths = result.failed_files.map do |spec|
                spec[:file_path]
              end
              @local_failed_test_command = %Q`#{@local_test_command} TEST_CMD="rspec #{failed_file_paths.join(' ')}"`
            end

            break
          end
        end
        break
      end
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
