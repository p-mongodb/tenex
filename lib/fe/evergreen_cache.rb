require 'fileutils'
require 'pathname'

module EvergreenCache

  module_function def logs_path
    Pathname.new(File.expand_path('~/.cache/tnex/eg-logs'))
  end

  module_function def build_log(build, which)
    cached_build = EgBuild.find_or_create_by(id: build.id)
    log_url = build.send("#{which}_log_url")
    log_path = logs_path.join("#{build.id}--#{which}.log")
    if build.finished? && build.finished_at == cached_build.finished_at && log_path.exist?
      log = File.read(log_path)
    else
      cached_build.finished_at = build.finished_at
      log = build.send("#{which}_log")
      if build.finished?
        cached_build.send("#{which}_log_url=", log_url)
        FileUtils.mkdir_p(log_path.dirname)
        File.open(log_path, 'w') do |f|
          f << log
        end
      else
        cached_build.send("#{which}_log_url=", nil)
      end
      cached_build.save!
    end
    [log, log_url]
  end
end
