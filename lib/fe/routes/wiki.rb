require 'confluence/client'

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
    p @info.body
    @body = @info.body['editor']['value']

    slim :wiki_edit
  end

  post '/wiki/update/:id' do |id|
    info = confluence_client.get_page(id)
    body = params[:body]
    payload = {
      type: 'page',
      title: params[:title],
      body: {
        storage: {value: body, representation: 'editor'},
      },
      version: {number: info['version']['number'] + 1},
    }
    #byebug
    confluence_client.update_page(id, payload)

    redirect "/wiki/edit/#{id}"
  end

end
