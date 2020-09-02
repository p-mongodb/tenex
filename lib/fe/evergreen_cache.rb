autoload :Oj, 'oj'
require 'fileutils'
require 'pathname'
require 'digest/sha1'

module EvergreenCache

  module_function def build_log(build, which)
    log_impl(EgBuild, build, which)
  end

  module_function def task_log(task, which)
    log_impl(EgTask, task, which).tap do |cached_obj, lines, log_url|
      unless cached_obj.build_id
        cached_obj.build_id = task.build_id
        cached_obj.save!
      end
    end
  end

  private

  module_function def log_impl(model_cls, eg_obj, which)
    cached_obj = model_cls.find_or_create_by(id: eg_obj.id)
    log_url = eg_obj.send("#{which}_log_url")
    log_path = logs_path.join("#{Digest::SHA1.new.update(eg_obj.id).hexdigest}--#{which}.log.json")
    if eg_obj.finished? && eg_obj.finished_at == cached_obj.finished_at && log_path.exist?
      lines = Oj.load(File.read(log_path)).map!(&:symbolize_keys)
    else
      cached_obj.finished_at = eg_obj.finished_at
      lines, truncated = retrieve_log(eg_obj, cached_obj, which)
      if eg_obj.finished?
        cached_obj.send("#{which}_log_url=", log_url)
        FileUtils.mkdir_p(log_path.dirname)
        File.open(log_path.to_s + '.part', 'w') do |f|
          f << lines.to_json
        end
        FileUtils.move(log_path.to_s + '.part', log_path)
      else
        cached_obj.send("#{which}_log_url=", nil)
      end
      cached_obj.save!
    end
    [cached_obj, lines, log_url]
  end

  module_function def retrieve_log(build, cached_build, which)
    log, truncated = build.send("sensible_#{which}_log")

    # Evergreen provides logs in html and text formats.
    # Unfortunately text format drops each line's severity which indicates,
    # in particular, the output stream (stdout/stderr) that the
    # line came from.
    # Convert html logs to the underlying log structure.
    #
    # Nokogiri has special handling of escape characters, bypass it to allow
    # us to run individual lines through ansi->html conversion.
    doc = Nokogiri::HTML(log.gsub("\x1b", "\ufff9"))
    lines = []
    elts = doc.xpath('//i')
    elts.each_with_index do |line, index|
      if index == elts.length - 1 && !line.attr('id')
        # truncated line
        if truncated
          break
        else
          raise "Apparently truncated line but log is not marked truncated"
        end
      end
      num = line.attr('id').sub(/.*-/, '').to_i + 1
      span = line.xpath('./following-sibling::span[1]').first
      # Truncated log lines may be missing the line number.
      unless span
        if index == elts.length - 1
          break
        else
          raise "Malformed line: #{line.to_s}"
        end
      end
      # Truncated log lines may not have a severity
      severity = span.attr('class').split(/\s+/).detect { |c| c.start_with?('severity-') }&.sub(/.*-/, '')&.downcase
      # If log line is truncated, set severity to error
      if severity.nil?
        if truncated
          severity = 'E'
        else
          raise "Missing severity and log file not marked truncated"
        end
      end
      text = span.text.gsub("\ufff9", "\x1b")
      # Remove priority. https://jira.mongodb.org/browse/EVG-7615
      text.sub!(/\A\[P: \d+\] /, '')
      if text =~ /\A\[.+?\] \[egos:(.) (.+?\d{3})\d{3}\]( .*)?\z/
        stream, time, rest = $1, $2, $3
        severity = {'O' => 'I', 'E' => 'E'}[stream] || 'E'
        text = "[#{time.sub('T', ' ')}]#{rest}"
      end
      # The formatter outputs its own date/time, which is redundant with
      # egos date and time. Note that formatter does not output milliseconds
      # while egos does; keep egos timestamp
      text.sub!(/\A(\[[-0-9 :.]+\]) \[[-0-9 :+]+\]/, "\\1")
      html = Ansi::To::Html.new(CGI.escapeHTML(text)).to_html
      lines << {num: num, severity: severity, text: text, html: html}
    end

    cached_build.first_failure_index = nil
    cached_build.mo_curl_failure_index = nil
    cached_build.bundler_failure_index = nil

    lines.each_with_index do |line, index|
      if line[:text] =~ %r,Failure/Error:,
        cached_build.first_failure_index ||= index
      end
      if line[:text] =~ /\[.*?\] curl: \(\d+\) Recv failure:/
        cached_build.mo_curl_failure_index = index
      end
      if line[:text] =~ /Unfortunately, an unexpected error occurred, and Bundler cannot continue./
        cached_build.bundler_failure_index = index
        lines.each_with_index do |l, i|
          if l[:text] =~ %r,https://github.com/bundler/bundler/issues/new,
            cached_build.bundler_failure_index = index
          end
        end
      end
    end

    if truncated
      lines << {
        num: lines.length, severity: 'E', text: 'LOG TRUNCATED',
        html: %q,<span color='red'>LOG TRUNCATED</span>,,
      }
    end

    [lines, truncated]
  end

  module_function def logs_path
    Pathname.new(File.expand_path('~/.cache/tnex/eg-logs'))
  end
end
