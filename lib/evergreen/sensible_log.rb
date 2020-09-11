module Evergreen
  module SensibleLog
    %i(task all).each do |which|

      # Retrieves at most 10 mb of log data.
      # Evergreen provides no indication of how big the log is, and
      # simply closes the connection if any request takes over a minute.
      # Currently log transfer rate is about 1 mb/s, thus retrieve up to
      # 10 mb which should take about 10 seconds.
      # https://jira.mongodb.org/browse/EVG-12428
      define_method("sensible_#{which}_log") do
        curl = Curl::Easy.new(public_send("#{which}_log_url"))
        curl.headers['user-agent'] = 'EvergreenRubyClient'
        curl.headers['api-user'] = client.username
        curl.headers['api-key'] = client.api_key
        #curl.verbose = true

        status = nil
        headers = {}
        curl.on_header do |data|
          if status.nil?
            if data =~ %r,\AHTTP/[0-9.]+ (\d+) ,
              status = $1.to_i
              if status != 200
                raise "Failed to retrieve logs: status #{status} for #{url}"
              end
            end
          elsif data =~ /:/
            bits = data.split(':', 2)
            headers[bits.first.strip.downcase] = bits.last.strip
          end
          data.length
        end

        body = ''
        curl.on_body do |chunk|
          body += chunk
          if body.length > 10_000_000
            raise BodyTooLarge
          end
          chunk.length
        end

        begin
          curl.perform
          truncated = false
        rescue BodyTooLarge
          truncated = true
        end

        unless headers['content-type'] && headers['content-type'] =~ /charset=utf-8/i
          warn "Missing content-type or not in UTF-8"
        end

        # Assume UTF-8 anyway otherwise we can't regexp match downstream
        body.force_encoding('utf-8')

        [body, truncated]
      end
    end
  end
end
