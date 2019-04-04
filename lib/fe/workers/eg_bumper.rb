require 'sidekiq'

class EgBumper
  include Sidekiq::Worker

  def perform
    puts "bumping"
  end
end
