require 'sidekiq'

class ResultFetcher
  include Sidekiq::Worker

  def do_perform
    Project.where(workflow: true).each do |project|
      puts "fetching for #{project.slug}"
    end
  end

  def perform
    do_perform
  rescue => e
    puts "#{e.class}: #{e}"
    puts e.backtrace.join("\n")
    raise
  end
end

puts 'hai'
