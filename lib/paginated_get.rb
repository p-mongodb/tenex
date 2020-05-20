autoload :Oj, 'oj'
autoload :LinkHeader, 'link_header'

module PaginatedGet
  def paginated_get(url)
    if block_given?
      yielding_paginated_get(url) do |item|
        yield item
      end
    else
      list = []
      yielding_paginated_get(url) do |item|
        list << item
      end
      list
    end
  end

  private def yielding_paginated_get(url)
    resp = connection.get(url)
    if resp.status != 200
      raise "Bad status #{resp.status}"
    end
    payload = Oj.load(resp.body)

    while true
      payload.each do |item|
        yield item
      end

      link_header = resp.headers['link']
      link = LinkHeader.parse(link_header)
      next_link = link.find_link(%w(rel next))
      if next_link.nil?
        break
      end

      resp = connection.get(next_link.href)
      while resp.status >= 300 && resp.status < 400
        # https://jira.mongodb.org/browse/EVG-5169
        resp = connection.get(resp.headers['location'])
      end
      if resp.status != 200
        raise "Bad status #{resp.status}"
      end
      payload = Oj.load(resp.body)
    end
    nil
  end
end
