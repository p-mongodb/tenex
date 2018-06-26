module Evergreen
  class Task
    def initialize(client, id)
      @client = client
      @id = id
    end

    attr_reader :client, :id

    def info
      @info ||= client.get_json("tasks/#{id}")
    end
  end
end
