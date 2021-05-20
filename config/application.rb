require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)


module Crowdstaffing
  class Application < Rails::Application
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end
    config.cache_store = :redis_store, "redis://#{ENV['REDIS_HOST'] || '127.0.0.1:6379'}/1", { expires_in: 1.month }
    config.active_job.queue_adapter = :sidekiq
    config.action_dispatch.perform_deep_munge = false

    config.active_record.dump_schemas = "public"

    config.tmp_path = ENV['TMP_PATH']
    config.elasticsearch = config_for(:elasticsearch)
    config.scout_apm = config_for(:scout_apm)
    config.support_emails = %w(suratp@crowdstaffing.com)
  end
end
