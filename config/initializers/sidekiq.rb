redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.error_handlers << ->(exception, context) do
    Rails.logger.error("Sidekiq error: #{exception.message}")
    Rails.logger.error("Context: #{context}")
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
