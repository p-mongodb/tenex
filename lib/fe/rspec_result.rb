autoload :Oj, 'oj'

class RspecResult
  class EmptyContent < ArgumentError
  end

  def initialize(url, content)
    @url = url
    if content.nil?
      raise EmptyContent, 'Content is nil'
    end
    if content.empty?
      raise EmptyContent, 'Content is an empty string'
    end
    @payload = Oj.load(content)
  end

  attr_reader :payload

  def jruby?
    !!(@url =~ /jruby/)
  end

  def summary
    if @payload.keys == %w(version)
      raise 'Result file has only version in it, something went terribly wrong'
    end
    @summary ||= {}.tap do |summary|
      @payload['summary'].each do |k, v|
        summary[k.to_sym] = v
      end
    end
  end

  def results
    @results ||= @payload['examples'].map do |info|
      {
        id: info['id'],
        description: info['full_description'],
        file_path: info['file_path'],
        line_number: info['line_number'],
        time: info['run_time'],
        started_at: info['started_at'],
        finished_at: info['finished_at'],
        sdam_log_entries: info['sdam_log_entries'],
        status: info['status'],
        pending_message: info['pending_message'],
      }.tap do |result|
        if info['status'] == 'failed'
          result[:failure] = {
            message: info['exception']['message'],
            class: info['exception']['class'],
            backtrace: info['exception']['backtrace'],
          }
        end
      end
    end
  end

  def failed_results
    results.select do |result|
      result[:failure]
    end
  end

  def succeeded_results
    results.select do |result|
      !result[:failure]
    end
  end

  # Failures outside of examples
  def messages
    @payload['messages']
  end

  def failed_files
    @failed_files ||= [].tap do |failed_files|
      failed_files_map = {}
      failed_results.each do |failure|
        failed_files_map[failure[:file_path]] ||= 0
        failed_files_map[failure[:file_path]] += 1
      end
      failed_files_map.keys.each do |key|
        failed_files << {
          file_path: key, failure_count: failed_files_map[key],
        }
      end
    end
  end

  def slowest_examples
    calculate_slowest_examples
    @slowest_examples
  end

  def slowest_total_time
    calculate_slowest_examples
    @slowest_total_time
  end

  private def calculate_slowest_examples
    return if @slowest_examples
    results_by_time = results.sort_by do |result|
      -(result[:time] || 0)
    end
    @slowest_examples = results_by_time[0..19]
    @slowest_total_time = @slowest_examples.inject(0) do |sum, result|
      sum + result[:time]
    end
  end

  def render_failure_count
    "#{summary[:failure_count]} failures"
  end
end
