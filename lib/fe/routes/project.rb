Routes.included do

  # pull
  get '/projects/:slug' do |slug|
    @project = project_by_slug(slug)

    slim :project_settings
  end

  post '/projects/:slug/settings' do |slug|
    project = project_by_slug(slug)
    project.workflow = params[:workflow] == 'on'
    project.evergreen = params[:evergreen] == 'on'
    project.travis = params[:travis] == 'on'
    project.save!
    redirect "/projects/#{project.slug}"
  end
end
