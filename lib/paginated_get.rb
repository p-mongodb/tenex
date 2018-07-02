module PaginatedGet
  def paginated_get(url)
    resp = connection.get(url)
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
      payload = JSON.parse(resp.body)
    end
    prev += payload
  end
end
