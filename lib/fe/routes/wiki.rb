require 'confluence/client'
require 'htmlentities'

Routes.included do

  get '/wiki' do
    @recent_pages = RecentWikiPage.order(last_hit_at: -1).limit(15)
    slim :wiki
  end

  post '/wiki/edit' do
    url = params[:url]
    id = nil

    if url =~ %r,pageId=(\d+),
      id = $1.to_i
    elsif url =~ %r,/display/(.+)/(.+)$,
      space, title = $1, $2
    else
      raise "Unknown URL format"
    end

    if id.nil? && space && title
      info = confluence_client.find_page_by_space_and_title(space, title)
      id = info['id'].to_i
    end

    if id.nil?
      raise 'Could not figure out page id'
    end

    redirect "/wiki/edit/#{id}"
  end

  get '/wiki/edit/:id' do |id|
    info = confluence_client.get_page(id)
    @info = OpenStruct.new(info)
    content = @info.body['editor']['value']
    if content.include?('{wiki}')
      parts = content.split('{wiki}')
      wiki_content = parts[1]
    else
      wiki_content = content
    end
    @body = HTMLEntities.new.decode(wiki_content)

    hit_wiki(id, info)

    slim :wiki_edit
  end

  post '/wiki/update/:id' do |id|
    info = confluence_client.get_page(id)
    body = params[:body]
    encoded_body = HTMLEntities.new.encode(body)
    content = info['body']['editor']['value']
    if content.include?('{wiki}')
      parts = content.split('{wiki}')
      parts[1] = encoded_body
      new_body = parts.join('{wiki}')
    else
      new_body = <<-EOT
<p><table class="wysiwyg-macro" data-macro-name="unmigrated-inline-wiki-markup" data-macro-id="719b0242-5a91-45df-b15a-088350d631fd" data-macro-parameters="atlassian-macro-output-type=INLINE" data-macro-schema-version="1" style="background-image: url(/plugins/servlet/confluence/placeholder/macro-heading?definition=e3VubWlncmF0ZWQtaW5saW5lLXdpa2ktbWFya3VwOmF0bGFzc2lhbi1tYWNyby1vdXRwdXQtdHlwZT1JTkxJTkV9&amp;locale=en_GB&amp;version=2); background-repeat: no-repeat;" data-macro-body-type="PLAIN_TEXT"><tr><td class="wysiwyg-macro-body"><pre>
{wiki}#{encoded_body}{wiki}
</pre></td></tr></table></p>
EOT
    end
    payload = {
      type: 'page',
      title: params[:title],
      body: {
        storage: {value: new_body, representation: 'editor'},
      },
      version: {number: info['version']['number'] + 1},
    }
    confluence_client.update_page(id, payload)

    hit_wiki(id, info)

    redirect "/wiki/edit/#{id}"
  end

  private def hit_wiki(id, info)
    rwp = RecentWikiPage.where(id: id).first
    if rwp.nil?
      unless info['space']
        raise "Space not in info, it must be requested"
      end
      rwp = RecentWikiPage.new(
        id: id,
        space_name: info['space']['name'],
        title: info['title'],
      )
    end
    rwp.last_hit_at = Time.now
    rwp.save!
  end

end
