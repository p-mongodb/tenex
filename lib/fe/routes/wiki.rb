require 'confluence/client'
require 'htmlentities'

Routes.included do

  get '/wiki' do
    slim :wiki
  end

  post '/wiki/edit' do
    url = params[:url]

    if url =~ %r,/display/(.+)/(.+)$,
      space, title = $1, $2
    else
      raise "Ugh"
    end

    info = confluence_client.find_page_by_space_and_title(space, title)
    id = info['id'].to_i

    redirect "/wiki/edit/#{id}"
  end

  get '/wiki/edit/:id' do |id|
    info = confluence_client.get_page(id)
    @info = OpenStruct.new(info)
    parts = @info.body['editor']['value'].split('{wiki}')
    @body = HTMLEntities.new.decode(parts[1])

    slim :wiki_edit
  end

  post '/wiki/update/:id' do |id|
    info = confluence_client.get_page(id)
    body = params[:body]
    parts = info['body']['editor']['value'].split('{wiki}')
    parts[1] = HTMLEntities.new.encode(body)
    new_body = parts.join('{wiki}')
    payload = {
      type: 'page',
      title: params[:title],
      body: {
        storage: {value: new_body, representation: 'editor'},
      },
      version: {number: info['version']['number'] + 1},
    }
    #byebug
    confluence_client.update_page(id, payload)

    redirect "/wiki/edit/#{id}"
  end

end
