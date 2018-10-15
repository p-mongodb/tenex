require 'sidekiq'
require 'sidekiq-cron'

require_relative './eg_bumper'

schedule_file = File.join(File.dirname(__FILE__), "schedule.yml")

Sidekiq::Cron::Job.load_from_hash(YAML.load(File.read(schedule_file)))
