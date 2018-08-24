module Evergreen
  class Artifact
    def initialize(client, info:)
      @client = client
      @info = info
    end

    attr_reader :client, :info

    %w(name url visibility ignore_for_fetch).each do |m|
      define_method(m) do
        info[m]
      end
    end
  end
end
