Routes.included do

  get '/travis/log/:job_id' do |job_id|
    status = Github::Pull::TravisStatus.new(OpenStruct.new(id: job_id))
    log = open(status.raw_log_url).read
    html_log = Ansi::To::Html.new(log).to_html.gsub("\n", '<br>')
  end
end
