# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Forecasts', :caching do
  let(:address) { '1600 Amphitheatre Parkway, Mountain View, CA' }

  describe 'GET /' do
    it 'shows the search form' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="address"', 'value="fahrenheit" checked="checked"')
    end
  end

  describe 'GET /forecast' do
    let(:params) { { address: address } }

    before do
      stub_nominatim
      stub_open_meteo
    end

    it 'shows the forecast in fahrenheit by default' do
      get forecast_path, params: params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('94043', '68°F', 'feels like 66°F', 'high 77°F', 'low 50°F', 'Slight rain')
    end

    it 'shows that the result is fresh' do
      get forecast_path, params: params

      expect(response.body).to include('Fresh result')
    end

    context 'when the unit is celsius' do
      let(:params) { { address: address, unit: 'celsius' } }

      it 'shows the forecast in celsius' do
        get forecast_path, params: params

        expect(response.body).to include('20°C', 'high 25°C', 'low 10°C')
      end
    end

    context 'when the zip code was requested before' do
      before { get forecast_path, params: { address: 'Shoreline Amphitheatre, Mountain View' } }

      it 'shows that the result came from the cache' do
        get forecast_path, params: params

        expect(response.body).to include('Cached result')
        expect(a_request(:get, /open-meteo/)).to have_been_made.once
      end
    end

    context 'when the address is blank' do
      let(:params) { { address: '   ' } }

      it 'shows the validation error without calling the APIs' do
        get forecast_path, params: params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Address can&#39;t be blank')
        expect(a_request(:get, /nominatim/)).not_to have_been_made
      end
    end

    context 'when the address is not found' do
      before { stub_nominatim(body: []) }

      it 'shows an error' do
        get forecast_path, params: params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('We could not find this address')
      end

      it 'keeps the address in the form' do
        get forecast_path, params: params

        expect(response.body).to include(%(value="#{address}"))
      end
    end

    context 'when the address has no zip code' do
      before { stub_nominatim(postcode: nil) }

      it 'asks for a more specific address' do
        get forecast_path, params: params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('We could not find a zip code for this address')
      end
    end

    context 'when the weather API is down' do
      before { stub_open_meteo(status: 503) }

      it 'shows a friendly error' do
        get forecast_path, params: params

        expect(response).to have_http_status(:service_unavailable)
        expect(response.body).to include('The weather service is unavailable right now')
      end
    end

    context 'when the geocoding API times out' do
      before { stub_request(:get, /nominatim/).to_timeout }

      it 'shows a friendly error' do
        get forecast_path, params: params

        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end

  describe 'GET /forecast.json' do
    before do
      stub_nominatim
      stub_open_meteo
    end

    it 'returns the forecast' do
      get forecast_path(format: :json), params: { address: address, unit: 'celsius' }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        'address' => address,
        'cached' => false,
        'location' => include('zip_code' => '94043', 'country_code' => 'us'),
        'forecast' => include('unit' => 'celsius', 'current_temperature' => 20.0, 'days' => be_an(Array))
      )
    end

    it 'returns cached as true in the second request' do
      2.times { get forecast_path(format: :json), params: { address: address } }

      expect(response.parsed_body['cached']).to be(true)
    end

    context 'when the unit is not supported' do
      it 'returns the validation error' do
        get forecast_path(format: :json), params: { address: address, unit: 'kelvin' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq('error' => 'Unit is not included in the list')
      end
    end

    context 'when the weather API returns an invalid body' do
      before do
        stub_request(:get, /open-meteo/)
          .to_return(status: 200, body: 'not json', headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns 503 with the error' do
        get forecast_path(format: :json), params: { address: address }

        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body['error']).to include('unavailable')
      end
    end
  end
end
