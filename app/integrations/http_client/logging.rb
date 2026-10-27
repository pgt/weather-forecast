# frozen_string_literal: true

class HttpClient
  module Logging
    def get(path, params = {})
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      super.tap { |response| log(path, response, started_at) }
    end

    private

    def log(path, response, started_at)
      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

      Rails.logger.info(
        "[HttpClient] GET #{URI(url).host}#{path} status=#{response.error || 'ok'} duration=#{duration}ms"
      )
    end
  end
end
