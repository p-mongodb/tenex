module Evergreen
  module Utils
    def convert_time(time_str)
      time = nil
      if time_str
        time = Time.parse(time_str)

        # Evergreen uses "1970-01-01T00:00:00Z" as a time when it doesn't
        # have a time value, for example finish time for a task that is not
        # finished.
        if time.to_i == 0
          time = nil
        end
      end
      time
    end
  end
end
