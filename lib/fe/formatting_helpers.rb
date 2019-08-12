module FormattingHelpers
  def sdam_log_entries(result)
    if result[:sdam_log_entries] && !result[:sdam_log_entries].empty?
      str = '<pre>'
      if result[:started_at]
        str << "#{h(result[:started_at])} | &lt;started&gt;\n"
      end
      result[:sdam_log_entries].each do |entry|
        str << "#{h(entry)}\n"
      end
      if result[:finished_at]
        str << " #{h(result[:finished_at])} | &lt;finished&gt;\n"
      end
      str << '</pre>'
      str.html_safe
    else
      nil
    end
  end

  def h(str)
    CGI.escapeHTML(str)
  end
end
