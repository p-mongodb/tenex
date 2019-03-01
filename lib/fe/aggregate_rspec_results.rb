class AggregateRspecResults
  def initialize(urls)
    @components = urls.map do |url|
      local_path = ArtifactCache.instance.fetch_artifact(url)
      content = File.open(local_path).read
      if content.empty?
        # Some tests produce empty rspec.json files.
        # Since we also aggregate on partial test results, ignore empty files
        # too.
        nil
      else
        RspecResults.new(content)
      end
    end.compact
  end

  def summary
    @summary ||= {}.tap do |summary|
      @components.each do |component|
        component.summary.each do |k, v|
          summary[k] ||= 0
          summary[k] += v
        end
      end
    end
  end

  def results
    @components.map do |component|
      component.results
    end.flatten
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
    @components.map do |component|
      component.messages
    end.compact
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

  def inspect
    "#<AggregateRspecResults:#{object_id}>"
  end

  def always_skipped_examples
    @always_skipped_examples ||= begin
        example_ids = results.map do |result|
        result[:id]
      end.uniq
      not_pending_example_ids = results.select do |result|
        result[:status] != 'pending'
      end.map do |result|
        result[:id]
      end.uniq
      pending_ids = example_ids - not_pending_example_ids
      pending_ids.map do |id|
        pending_messages = @components.map do |results|
          result = results.results.detect do |result|
            result[:id] == id
          end
          unless result
            raise "Failed to find result for #{id}"
          end
          result[:pending_message]
        end.uniq.join('; ')
        {id: id, status: 'pending', pending_messages: pending_messages}
      end
    end
  end
end
