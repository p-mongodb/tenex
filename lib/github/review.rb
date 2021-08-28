require 'forwardable'

module Github
  class Review
    extend Forwardable

    def_delegators :@info, :[], :[]=

    def initialize(client, info: nil)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(id body).each do |meth|
      define_method(meth) do
        @info.fetch(meth)
      end
    end

    def comments
      @comments ||= client.get_json("#{info.fetch('pull_request_url')}/reviews/#{id}/comments").map do |info|
        ReviewComment.new(client, info: info)
      end
    end
  end
end
