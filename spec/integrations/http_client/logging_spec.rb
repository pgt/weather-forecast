# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HttpClient::Logging do
  subject(:get) { HttpClient.new(url: 'https://api.example.com').get('/search', q: '1600 Amphitheatre Parkway') }

  let(:endpoint) { %r{\Ahttps://api.example.com/search} }

  before { allow(Rails.logger).to receive(:info) }

  context 'when the request succeeds' do
    before { stub_request(:get, endpoint).to_return(status: 200, body: '{}') }

    it 'logs the host, path and duration' do
      get

      expect(Rails.logger).to have_received(:info).with(
        %r{\A\[HttpClient\] GET api.example.com/search status=ok duration=\d+ms\z}
      )
    end

    it 'does not log the params' do
      get

      expect(Rails.logger).not_to have_received(:info).with(/Amphitheatre/)
    end
  end

  context 'when the request fails' do
    before { stub_request(:get, endpoint).to_return(status: 400, body: '') }

    it 'logs the error' do
      get

      expect(Rails.logger).to have_received(:info).with(/status=invalid_response/)
    end
  end
end
