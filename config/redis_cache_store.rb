# frozen_string_literal: true

module WeatherForecast
  module RedisCacheStore
    def self.options
      {
        url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
        namespace: 'weather-forecast',
        connect_timeout: 1,
        read_timeout: 0.5,
        write_timeout: 0.5,
        reconnect_attempts: 1,
        pool: { size: Integer(ENV.fetch('RAILS_MAX_THREADS', 3)), timeout: 1 },
        error_handler: method(:handle_error)
      }
    end

    def self.handle_error(method:, returning:, exception:)
      Rails.logger.warn(
        "[RedisCacheStore] #{method} failed (returning #{returning.inspect}): " \
        "#{exception.class}: #{exception.message}"
      )
    end
  end
end
