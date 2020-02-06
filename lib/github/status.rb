require 'forwardable'

module Github
  class Status
    extend Forwardable

    def_delegators :@info, :[], :[]=

    def initialize(client, info: nil)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(context state).each do |meth|
      define_method(meth) do
        @info[meth]
      end
    end

    def updated_at
      Time.parse(info['updated_at'])
    end
  end
end
