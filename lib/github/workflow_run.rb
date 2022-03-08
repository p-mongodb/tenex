require 'forwardable'

module Github
  class WorkflowRun
    extend Forwardable

    def_delegators :@info, :[], :[]=

    def initialize(client, info: nil)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(status logs_url jobs_url).each do |meth|
      define_method(meth) do
        @info.fetch(meth)
      end
    end

    def jobs
      # TODO paginate
      client.get_json(jobs_url).fetch('jobs').map do |info|
        WorkflowJob.new(client, info: info)
      end
    end
  end
end
