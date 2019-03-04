Routes.included do

  get '/paste' do
    slim :paste
  end

  post '/paste' do
    description = params[:description]
    if description.blank?
      description = nil
    end
    basename = params[:basename]
    if basename.blank?
      basename = 'pasted.txt'
    end
    payload = {
      description: description || 'Tenex Paste',
      files: {
        basename => {content: params[:content]},
      }
    }
    rv = gh_client.post_json('/gists', payload)
    redirect rv['html_url']
  end
end
