gem 'addressable'
autoload :Addressable, 'addressable'

module FormattingHelpers
  def sdam_log_entries(result)
    if result[:sdam_log_entries] && !result[:sdam_log_entries].empty?
      str = '<pre>'
      if result[:started_at]
        str << "#{h(result[:started_at])} | &lt;started&gt;\n"
      end
      result[:sdam_log_entries].each do |entry|
        if entry
          str << "#{h(entry)}\n"
        end
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
    if task.finished?
      Taw.time_ago_in_words(Time.now - task.time_taken, approx: 2)
    elsif task.started_at
      "Running for #{Taw.time_ago_in_words(task.started_at, approx: 2)}"
    else
      "Waiting for #{Taw.time_ago_in_words(task.created_at, approx: 2)}"
    end
  end

  def short_task_runtime(task)
    if task.finished?
      render_time_delta(task.time_taken)
    elsif task.started_at
      render_time_delta(Time.now - task.started_at)
    elsif task.scheduled_at
      render_time_delta(Time.now - task.scheduled_at)
    # Task creation time is bogus - https://jira.mongodb.org/browse/EVG-7122
    # Use ingest time instead
    elsif task.ingested_at
      render_time_delta(Time.now - task.ingested_at)
    else
      render_time_delta(Time.now - task.created_at)
    end
  end

  def render_time_delta(delta)
    seconds = delta % 60
    minutes = (delta / 60).to_i
    "#{minutes}:#{'%02d' % seconds}"
  end

  def truncate(text, limit)
    if text.nil?
      nil
    elsif text.length > limit
      text[0...limit-3] + '...'
    else
      text
    end
  end

  def short_issue_type(issue_type_name)
    case issue_type_name
    when 'Epic'
      'Epic'
    when 'New Feature'
      'Feat'
    when 'Improvement'
      'Imp'
    when 'Task'
      'Task'
    when 'Bug'
      'Bug'
    else
      issue_type_name
    end
  end

  def build_timing(build)
    if build.running?
      if build.expected_duration
        suffix = " out of ~ #{Taw.time_ago_in_words(Time.now - build.expected_duration, approx: 2)}"
      else
        suffix = ''
      end
      elapsed_time = Taw.time_ago_in_words(build.started_at, approx: 2)
      " (for #{elapsed_time}#{suffix})"
    else
      ''
    end
  end

  def escape_uri(uri)
    Addressable::URI.encode(uri)
  end
end
