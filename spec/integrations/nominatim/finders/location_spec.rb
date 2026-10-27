# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Nominatim::Finders::Location do
  subject(:finder) { described_class.new }

  describe '#find', :vcr do
    subject(:find) { finder.find(address) }

    let(:address) { '1600 Amphitheatre Parkway, Mountain View, CA' }

    it 'returns the location with the zip code' do
      is_expected.to have_attributes(
        zip_code: '94043',
        country_code: 'us',
        latitude: be_within(0.01).of(37.42),
        longitude: be_within(0.01).of(-122.08),
        display_name: include('Mountain View')
      )
    end

    context 'when the address is only a city' do
      let(:address) { 'Mountain View, CA' }

      it 'returns the location without zip code' do
        is_expected.to have_attributes(zip_code: nil, country_code: 'us')
      end
    end

    context 'when the address does not exist' do
      let(:address) { 'qwzxv lkjhg poiuy, nowhere land' }

      it 'returns nil with the error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:address_not_found)
      end
    end
  end

  describe '#find with stubbed responses' do
    subject(:find) { finder.find('foo') }

    let(:endpoint) { %r{\Ahttps://nominatim.openstreetmap.org/search} }
    let(:place) do
      {
        lat: '40.7484',
        lon: '-73.9857',
        display_name: '350, 5th Avenue, New York, 10118, United States',
        address: { postcode: postcode, country_code: 'us' }
      }
    end
    let(:postcode) { '10118' }
    let(:body) { [place].to_json }
    let(:status) { 200 }

    before do
      stub_request(:get, endpoint)
        .with(headers: { 'User-Agent' => 'weather-forecast/1.0' })
        .to_return(status: status, body: body, headers: { 'Content-Type' => 'application/json' })
    end

    it 'converts lat/lon into floats' do
      expect(find).to have_attributes(latitude: 40.7484, longitude: -73.9857)
    end

    context 'when the postcode is in the ZIP+4 format' do
      let(:postcode) { '10118-0110' }

      it 'keeps only the 5-digit zip code' do
        expect(find.zip_code).to eq('10118')
      end
    end

    context 'when the postcode has more than one value' do
      let(:postcode) { '10118; 10119' }

      it 'keeps only the first one' do
        expect(find.zip_code).to eq('10118')
      end
    end

    context 'when the postcode is not from US' do
      let(:postcode) { 'SW1A 1AA' }

      it 'keeps the original value' do
        expect(find.zip_code).to eq('SW1A 1AA')
      end
    end

    context 'when the body is not a list' do
      let(:body) { { error: 'Unable to geocode' }.to_json }

      it 'returns nil with an invalid response error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:invalid_response)
      end
    end

    context 'when the place has an unexpected format' do
      let(:body) { [{ lat: 'not a number', address: {} }].to_json }

      it 'returns nil with an invalid response error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:invalid_response)
      end
    end

    context 'when the upstream is unavailable' do
      let(:status) { 503 }

      it 'returns nil with the upstream error' do
        expect(find).to be_nil
        expect(finder.error).to eq(:unavailable)
      end
    end
  end

  context 'when the user agent is customized' do
    subject(:find) { finder.find('foo') }

    before do
      stub_const('ENV', ENV.to_h.merge('NOMINATIM_USER_AGENT' => 'my-app (me@example.com)'))

      stub_request(:get, /nominatim/)
        .with(headers: { 'User-Agent' => 'my-app (me@example.com)' })
        .to_return(status: 200, body: '[]', headers: { 'Content-Type' => 'application/json' })
    end

    it 'sends it in the request' do
      find

      expect(finder.error).to eq(:address_not_found)
    end
  end
end
