require 'forwardable'

module Github
  class Comment
    extend Forwardable

    def_delegators :@info, :[], :[]=

    def initialize(client, info: nil)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(body).each do |meth|
      define_method(meth) do
        @info[meth]
      end
    end
  end
end
