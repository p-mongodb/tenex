require 'sidekiq'
require 'sidekiq-cron'

$: << 'lib'

require_relative '../boot'
require_relative './eg_bumper'
require_relative './result_fetcher'

schedule_file = File.join(File.dirname(__FILE__), "../../../config/schedule.yml")

Sidekiq::Cron::Job.load_from_hash(YAML.load(File.read(schedule_file)))
