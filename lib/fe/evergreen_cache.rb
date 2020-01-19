require 'fileutils'
require 'pathname'

module EvergreenCache

  module_function def build_log(build, which)
    cached_build = EgBuild.find_or_create_by(id: build.id)
    log_url = build.send("#{which}_log_url")
    log_path = logs_path.join("#{build.id}--#{which}.log.json")
    if build.finished? && build.finished_at == cached_build.finished_at && log_path.exist?
      lines = JSON.parse(File.read(log_path)).map!(&:symbolize_keys)
    else
      cached_build.finished_at = build.finished_at
      lines = retrieve_log(build, cached_build, which)
      if build.finished?
        cached_build.send("#{which}_log_url=", log_url)
        FileUtils.mkdir_p(log_path.dirname)
        File.open(log_path.to_s + '.part', 'w') do |f|
          f << lines.to_json
        end
        FileUtils.move(log_path.to_s + '.part', log_path)
      else
        cached_build.send("#{which}_log_url=", nil)
      end
      cached_build.save!
    end
    [cached_build, lines, log_url]
  end

  private

  module_function def retrieve_log(build, cached_build, which)
    log = build.send("#{which}_log")

    # Evergreen provides logs in html and text formats.
    # Unfortunately text format drops each line's severity which indicates,
    # in particular, the output stream (stdout/stderr) that the
    # line came from.
    # Convert html logs to the underlying log structure.
    #
    # Nokogiri has special handling of escape characters, bypass it to allow
    # us to run individual lines through ansi->html conversion.
    doc = Nokogiri::HTML(log.gsub("\x1b", "\ufff9"))
    lines = doc.xpath('//i').map do |line|
      num = line.attr('id').sub(/.*-/, '').to_i + 1
      span = line.xpath('./following-sibling::span[1]').first
      severity = span.attr('class').split(/\s+/).detect { |c| c.start_with?('severity-') }.sub(/.*-/, '').downcase
      text = span.text.gsub("\ufff9", "\x1b")
      html = Ansi::To::Html.new(CGI.escapeHTML(text)).to_html
      {num: num, severity: severity, text: text, html: html}
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

    lines
  end

  module_function def logs_path
    Pathname.new(File.expand_path('~/.cache/tnex/eg-logs'))
  end
end
