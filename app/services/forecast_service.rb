# frozen_string_literal: true

class ForecastService
  FORECAST_CACHE_OPTIONS = { expires_in: 30.minutes, race_condition_ttl: 10.seconds, skip_nil: true }.freeze
  GEOCODING_CACHE_OPTIONS = { expires_in: 1.day, skip_nil: true }.freeze
  CACHE_VERSION = 'v1'

  private_constant :FORECAST_CACHE_OPTIONS, :GEOCODING_CACHE_OPTIONS, :CACHE_VERSION

  def initialize(
    location_finder: Nominatim::Finders::Location.new,
    forecast_finder: OpenMeteo::Finders::Forecast.new
  )
    @location_finder = location_finder
    @forecast_finder = forecast_finder
  end

  def execute(address)
    location = find_location(address)

    return Result.new(error: location_finder.error) unless location
    return Result.new(error: :zip_code_not_found) if location.zip_code.blank?

    forecast_for(location)
  end

  private

  attr_reader :location_finder, :forecast_finder

  def forecast_for(location)
    cached = true
    forecast = Rails.cache.fetch(forecast_cache_key(location), **FORECAST_CACHE_OPTIONS) do
      cached = false
      forecast_finder.find(latitude: location.latitude, longitude: location.longitude)
    end

    return Result.new(error: forecast_finder.error) unless forecast

    Result.new(location: location, forecast: forecast, cached: cached)
  end

  def find_location(address)
    Rails.cache.fetch(geocoding_cache_key(address), **GEOCODING_CACHE_OPTIONS) do
      location_finder.find(address)
    end
  end

  def forecast_cache_key(location)
    "forecast/#{CACHE_VERSION}/#{location.cache_key}"
  end

  def geocoding_cache_key(address)
    "geocoding/#{CACHE_VERSION}/#{Digest::SHA256.hexdigest(address.to_s.squish.downcase)}"
  end
end
