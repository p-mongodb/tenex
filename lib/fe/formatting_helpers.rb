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
        str << "#{h(result[:finished_at])} | &lt;finished&gt;\n"
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

  def task_runtime(task)
    if task.completed?
      Taw.time_ago_in_words(Time.now - task.time_taken, approx: 2)
    elsif task.started_at
      "Running for #{Taw.time_ago_in_words(task.started_at, approx: 2)}"
    else
      "Waiting for #{Taw.time_ago_in_words(task.created_at, approx: 2)}"
    end
  end

  def short_task_runtime(task)
    if task.completed?
      render_time_delta(task.time_taken)
    elsif task.started_at
      render_time_delta(Time.now - task.started_at)
    else
      render_time_delta(Time.now - task.created_at)
    end
  end

  def render_time_delta(delta)
    seconds = delta % 60
    minutes = (delta / 60).to_i
    "#{minutes}:#{'%02d' % seconds}"
  end
end
