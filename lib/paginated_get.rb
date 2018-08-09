module PaginatedGet
  def paginated_get(url)
    resp = connection.get(url)
    if resp.status != 200
      raise "Bad status #{resp.status}"
    end
    payload = JSON.parse(resp.body)
    prev = []

    while link_header = resp.headers['link']
      link = LinkHeader.parse(link_header)
      next_link = link.find_link(%w(rel next))
      if next_link.nil?
        break
      end
      prev += payload
      resp = connection.get(next_link.href)
      while resp.status >= 300 && resp.status < 400
        # https://jira.mongodb.org/browse/EVG-5169
        resp = connection.get(resp.headers['location'])
      end
      if resp.status != 200
        raise "Bad status #{resp.status}"
      end
      payload = JSON.parse(resp.body)
    end
    prev += payload
  end
end
