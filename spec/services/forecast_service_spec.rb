# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForecastService, :caching do
  subject(:service) { described_class.new(location_finder: location_finder, forecast_finder: forecast_finder) }

  let(:location_finder) { instance_double(Nominatim::Finders::Location, find: location, error: nil) }
  let(:forecast_finder) { instance_double(OpenMeteo::Finders::Forecast, find: forecast, error: nil) }

  let(:location) do
    Location.new(
      zip_code: '94043',
      country_code: 'us',
      latitude: 37.42,
      longitude: -122.08,
      display_name: '1600, Amphitheatre Parkway, Mountain View, California, 94043, United States'
    )
  end
  let(:forecast) do
    Forecast.new(
      current_temperature: 18.0,
      feels_like: 17.0,
      condition: 'Clear sky',
      timezone: 'America/Los_Angeles',
      fetched_at: Time.current,
      days: []
    )
  end
  let(:address) { '1600 Amphitheatre Parkway, Mountain View, CA' }

  describe '#execute' do
    subject(:execute) { service.execute(address) }

    it { is_expected.to be_success }

    it 'returns the location and its forecast' do
      expect(execute).to have_attributes(location: location, forecast: forecast)
    end

    it 'looks for the forecast using the location coordinates' do
      execute

      expect(forecast_finder).to have_received(:find).with(latitude: 37.42, longitude: -122.08)
    end

    context 'when it is the first request for the zip code' do
      it { is_expected.not_to be_cached }
    end

    context 'when the zip code was requested less than 30 minutes ago' do
      before do
        service.execute(address)
        travel 29.minutes
      end

      it { is_expected.to be_cached }

      it 'does not call the weather API again' do
        execute

        expect(forecast_finder).to have_received(:find).once
      end

      it 'returns the same forecast' do
        expect(execute.forecast.attributes).to eq(forecast.attributes)
      end
    end

    context 'when the zip code was requested more than 30 minutes ago' do
      before do
        service.execute(address)
        travel 31.minutes
      end

      it { is_expected.not_to be_cached }

      it 'calls the weather API again' do
        execute

        expect(forecast_finder).to have_received(:find).twice
      end
    end

    context 'when another address has the same zip code' do
      before { service.execute('Shoreline Amphitheatre, Mountain View') }

      it { is_expected.to be_cached }
    end

    context 'when the same zip code exists in another country' do
      before do
        berlin = Location.new(location.attributes.merge('zip_code' => '10115', 'country_code' => 'de'))
        new_york = Location.new(location.attributes.merge('zip_code' => '10115', 'country_code' => 'us'))

        allow(location_finder).to receive(:find).and_return(berlin, new_york)

        service.execute('Invalidenstraße, Berlin')
      end

      it 'does not share the cache' do
        expect(service.execute('somewhere in New York')).not_to be_cached
      end
    end

    context 'when the same address is requested again' do
      before { service.execute(address) }

      it 'does not call the geocoding API again' do
        service.execute("  #{address.upcase} ")

        expect(location_finder).to have_received(:find).once
      end

      it 'keeps only a digest of the address in the cache key' do
        digest = Digest::SHA256.hexdigest(address.downcase)

        expect(Rails.cache.exist?("geocoding/v1/#{digest}")).to be(true)
      end
    end

    context 'when the address does not exist' do
      let(:location_finder) { instance_double(Nominatim::Finders::Location, find: nil, error: :address_not_found) }

      it 'returns the finder error' do
        expect(execute).not_to be_success
        expect(execute.error).to eq(:address_not_found)
      end

      it 'does not cache the miss' do
        2.times { service.execute(address) }

        expect(location_finder).to have_received(:find).twice
      end
    end

    context 'when the address has no zip code' do
      let(:location) { super().tap { |location| location.zip_code = nil } }

      it 'returns a zip code not found error' do
        expect(execute.error).to eq(:zip_code_not_found)
      end

      it 'does not look for the forecast' do
        execute

        expect(forecast_finder).not_to have_received(:find)
      end
    end

    context 'when the weather API fails' do
      let(:forecast_finder) { instance_double(OpenMeteo::Finders::Forecast, find: nil, error: :unavailable) }

      it 'returns the finder error' do
        expect(execute).not_to be_success
        expect(execute.error).to eq(:unavailable)
      end

      it 'does not cache the failure' do
        2.times { service.execute(address) }

        expect(forecast_finder).to have_received(:find).twice
      end
    end
  end
end
