# frozen_string_literal: true

module ApiStubs
  JSON_HEADERS = { 'Content-Type' => 'application/json' }.freeze
  private_constant :JSON_HEADERS

  def stub_nominatim(postcode: '94043', status: 200, body: nil)
    body ||= [
      {
        lat: '37.4224858',
        lon: '-122.0855846',
        display_name: '1600, Amphitheatre Parkway, Mountain View, California, 94043, United States',
        address: { postcode: postcode, country_code: 'us' }
      }
    ]

    stub_request(:get, %r{\Ahttps://nominatim.openstreetmap.org/search})
      .to_return(status: status, body: body.to_json, headers: JSON_HEADERS)
  end

  def stub_open_meteo(status: 200)
    stub_request(:get, %r{\Ahttps://api.open-meteo.com/v1/forecast})
      .to_return(status: status, body: open_meteo_body.to_json, headers: JSON_HEADERS)
  end

  private

  def open_meteo_body
    {
      timezone: 'America/Los_Angeles',
      current: { temperature_2m: 20.0, apparent_temperature: 19.0, weather_code: 0 },
      daily: {
        time: %w[2026-10-27 2026-10-28],
        temperature_2m_max: [25.0, 23.0],
        temperature_2m_min: [10.0, 11.0],
        weather_code: [0, 61]
      }
    }
  end
end

RSpec.configure do |config|
  config.include ApiStubs, type: :request
end
