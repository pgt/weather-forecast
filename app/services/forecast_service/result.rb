# frozen_string_literal: true

class ForecastService
  class Result
    attr_reader :location, :forecast, :error

    def initialize(location: nil, forecast: nil, cached: false, error: nil)
      @location = location
      @forecast = forecast
      @cached = cached
      @error = error
    end

    def cached?
      @cached
    end

    def success?
      error.nil?
    end
  end
end
