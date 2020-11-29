module Evergreen
  class EvergreenError < StandardError
  end

  class ApiError < EvergreenError
    def initialize(message, status: nil)
      super(message)
      @status = status
    end

    attr_reader :status
  end

  class NotFound < ApiError
  end

  class DistroNotFound < EvergreenError
  end
end
