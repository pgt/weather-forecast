# frozen_string_literal: true

class Forecast
  class Formatter
    UNITS = %w[fahrenheit celsius].freeze
    DEFAULT_UNIT = 'fahrenheit'

    SYMBOLS = { 'fahrenheit' => '°F', 'celsius' => '°C' }.freeze
    private_constant :SYMBOLS

    attr_reader :unit

    def initialize(forecast, unit: DEFAULT_UNIT)
      @forecast = forecast
      @unit = UNITS.include?(unit.to_s) ? unit.to_s : DEFAULT_UNIT
    end

    def temperature(celsius)
      "#{convert(celsius).round}#{SYMBOLS.fetch(unit)}"
    end

    def as_json(*)
      {
        unit: unit,
        **current_as_json,
        timezone: forecast.timezone,
        fetched_at: forecast.fetched_at.iso8601,
        days: forecast.days.map { |day| day_as_json(day) }
      }
    end

    private

    attr_reader :forecast

    def convert(celsius)
      return celsius if unit == 'celsius'

      (celsius * 9 / 5.0) + 32
    end

    def precise(celsius)
      convert(celsius).round(1)
    end

    def current_as_json
      {
        current_temperature: precise(forecast.current_temperature),
        feels_like: precise(forecast.feels_like),
        condition: forecast.condition
      }
    end

    def day_as_json(day)
      {
        date: day.date.iso8601,
        high: precise(day.high),
        low: precise(day.low),
        condition: day.condition
      }
    end
  end
end
