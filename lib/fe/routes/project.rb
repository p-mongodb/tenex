Routes.included do

  # pull
  get '/projects/:slug' do |slug|
    @project = project_by_slug(slug)

    slim :project
  end
end
