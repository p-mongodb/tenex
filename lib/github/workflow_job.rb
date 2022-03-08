require 'forwardable'

module Github
  class WorkflowJob
    extend Forwardable

    def_delegators :@info, :[], :[]=

    def initialize(client, info: nil)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(name status conclusion).each do |meth|
      define_method(meth) do
        @info.fetch(meth)
      end
    end

  end
end
