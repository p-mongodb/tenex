module Evergreen
  class ApiError < StandardError
    def initialize(message, status: nil)
      super(message)
      @status = status
    end

    attr_reader :status
  end

  class NotFound < ApiError; end
end
