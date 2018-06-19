module Evergreen
  class Version
    def initialize(client, id)
      @client = client
      @id = id
    end

    attr_reader :client, :id
  end
end
