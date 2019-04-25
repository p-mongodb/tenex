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
    p info
  end

end
