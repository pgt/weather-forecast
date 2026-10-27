# frozen_string_literal: true

module OpenMeteo
  module Finders
    class Forecast
      FORECAST_DAYS = 7
      private_constant :FORECAST_DAYS

      attr_reader :error

      def find(latitude:, longitude:)
        response = http_client.get('/v1/forecast', params(latitude, longitude))
        @error = response.error

        return unless response.success?
        return invalid_response unless response.body.is_a?(Hash)

        forecast = build_forecast(response.body)

        forecast.valid? ? forecast : invalid_response
      end

      private

      def params(latitude, longitude)
        {
          latitude: latitude,
          longitude: longitude,
          current: 'temperature_2m,apparent_temperature,weather_code',
          daily: 'temperature_2m_max,temperature_2m_min,weather_code',
          timezone: 'auto',
          forecast_days: FORECAST_DAYS
        }
      end

      def build_forecast(body)
        current = body['current'].to_h

        ::Forecast.new(
          current_temperature: Float(current['temperature_2m'], exception: false),
          feels_like: Float(current['apparent_temperature'], exception: false),
          condition: WeatherCodes.describe(current['weather_code']),
          days: build_days(body['daily'].to_h),
          timezone: body['timezone'],
          fetched_at: Time.current
        )
      end

      def build_days(daily)
        Array(daily['time']).each_with_index.map do |date, index|
          ::Forecast::Day.new(
            date: date,
            high: number_at(daily['temperature_2m_max'], index),
            low: number_at(daily['temperature_2m_min'], index),
            condition: WeatherCodes.describe(Array(daily['weather_code'])[index])
          )
        end
      end

      def number_at(values, index)
        Float(Array(values)[index], exception: false)
      end

      def invalid_response
        @error = :invalid_response
        nil
      end

      def http_client
        @http_client ||= Client.new.create
      end
    end
  end
end
