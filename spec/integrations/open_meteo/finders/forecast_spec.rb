# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OpenMeteo::Finders::Forecast do
  subject(:finder) { described_class.new }

  describe '#find', :vcr do
    subject(:find) { finder.find(latitude: 37.4225, longitude: -122.0856) }

    it 'returns the current temperature and the next 7 days' do
      expect(find).to have_attributes(
        current_temperature: be_a(Float),
        feels_like: be_a(Float),
        condition: be_a(String),
        timezone: 'America/Los_Angeles'
      )
      expect(find.days.size).to eq(7)
      expect(find.today).to have_attributes(date: be_a(Date), high: be_a(Float), low: be_a(Float))
    end
  end

  describe '#find with stubbed responses' do
    subject(:find) { finder.find(latitude: 40.75, longitude: -73.99) }

    let(:endpoint) { %r{\Ahttps://api.open-meteo.com/v1/forecast} }
    let(:body) do
      {
        timezone: 'America/New_York',
        current: { temperature_2m: 12.3, apparent_temperature: 10.1, weather_code: weather_code },
        daily: {
          time: %w[2026-10-27 2026-10-28],
          temperature_2m_max: [15.0, 17.5],
          temperature_2m_min: [8.0, 9.5],
          weather_code: [3, 61]
        }
      }
    end
    let(:weather_code) { 0 }
    let(:status) { 200 }

    before do
      stub_request(:get, endpoint)
        .to_return(status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'builds the forecast from the response' do
      expect(find).to have_attributes(current_temperature: 12.3, feels_like: 10.1, condition: 'Clear sky')
      expect(find.days.map { |day| day.attributes.symbolize_keys }).to eq(
        [
          { date: Date.new(2026, 10, 27), high: 15.0, low: 8.0, condition: 'Overcast' },
          { date: Date.new(2026, 10, 28), high: 17.5, low: 9.5, condition: 'Slight rain' }
        ]
      )
    end

    it 'sets when the forecast was fetched' do
      freeze_time do
        expect(find.fetched_at).to eq(Time.current)
      end
    end

    it 'asks for the forecast in the location timezone' do
      find

      expect(a_request(:get, endpoint).with(query: hash_including('timezone' => 'auto'))).to have_been_made
    end

    context 'when the weather code is unknown' do
      let(:weather_code) { 1234 }

      it 'does not fail' do
        expect(find.condition).to eq('Unknown')
      end
    end

    context 'when the current temperature is missing' do
      let(:body) { { timezone: 'UTC', current: { temperature_2m: nil }, daily: {} } }

      it 'returns nil with an invalid response error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:invalid_response)
      end
    end

    context 'when the daily values have an invalid date' do
      let(:body) do
        {
          timezone: 'UTC',
          current: { temperature_2m: 1, apparent_temperature: 1, weather_code: 0 },
          daily: { time: ['yesterday'], temperature_2m_max: [1], temperature_2m_min: [1], weather_code: [0] }
        }
      end

      it 'returns nil with an invalid response error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:invalid_response)
      end
    end

    context 'when the body is not an object' do
      let(:body) { [] }

      it 'returns nil with an invalid response error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:invalid_response)
      end
    end

    context 'when the coordinates are rejected' do
      let(:status) { 400 }
      let(:body) { { error: true, reason: 'Latitude must be in range of -90 to 90°. Given: 999.0.' } }

      it 'returns nil with an invalid response error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:invalid_response)
      end
    end
  end
end
