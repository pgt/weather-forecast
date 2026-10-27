# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Forecast::Formatter do
  subject(:formatter) { forecast.format(unit) }

  let(:unit) { 'fahrenheit' }
  let(:forecast) do
    Forecast.new(
      current_temperature: 21.5,
      feels_like: 20.0,
      condition: 'Overcast',
      timezone: 'America/Los_Angeles',
      fetched_at: Time.zone.parse('2026-10-27 15:30:00 UTC'),
      days: [Forecast::Day.new(date: Date.new(2026, 10, 27), high: 25.0, low: 10.0, condition: 'Drizzle')]
    )
  end

  describe '#unit' do
    it { expect(formatter.unit).to eq('fahrenheit') }

    context 'when the unit is not supported' do
      let(:unit) { 'kelvin' }

      it 'falls back to fahrenheit' do
        expect(formatter.unit).to eq('fahrenheit')
      end
    end

    context 'when the unit is nil' do
      let(:unit) { nil }

      it { expect(formatter.unit).to eq('fahrenheit') }
    end
  end

  describe '#temperature' do
    it 'converts from celsius and rounds' do
      expect(formatter.temperature(21.5)).to eq('71°F')
    end

    context 'when the unit is celsius' do
      let(:unit) { 'celsius' }

      it 'keeps the value and rounds' do
        expect(formatter.temperature(21.5)).to eq('22°C')
      end
    end
  end

  describe '#as_json' do
    subject(:as_json) { formatter.as_json }

    it 'returns all the values converted' do
      is_expected.to eq(
        unit: 'fahrenheit',
        current_temperature: 70.7,
        feels_like: 68.0,
        condition: 'Overcast',
        timezone: 'America/Los_Angeles',
        fetched_at: '2026-10-27T15:30:00Z',
        days: [{ date: '2026-10-27', high: 77.0, low: 50.0, condition: 'Drizzle' }]
      )
    end

    context 'when the unit is celsius' do
      let(:unit) { 'celsius' }

      it 'returns the original values' do
        expect(as_json).to include(current_temperature: 21.5, feels_like: 20.0)
        expect(as_json[:days].first).to include(high: 25.0, low: 10.0)
      end
    end
  end
end
