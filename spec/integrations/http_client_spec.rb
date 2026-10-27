# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HttpClient do
  subject(:http_client) { described_class.new(url: 'https://api.example.com', headers: headers) }

  let(:headers) { { 'User-Agent' => 'weather-forecast-test' } }
  let(:endpoint) { 'https://api.example.com/search?q=foo' }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  describe '#get' do
    subject(:get) { http_client.get('/search', q: 'foo') }

    context 'when the upstream answers successfully' do
      before do
        stub_request(:get, endpoint)
          .with(headers: headers)
          .to_return(status: 200, body: '{"foo":"bar"}', headers: json_headers)
      end

      it { is_expected.to be_success }

      it 'returns the parsed body' do
        expect(get.body).to eq('foo' => 'bar')
      end
    end

    context 'when the connection can not be opened in time' do
      before { stub_request(:get, endpoint).to_timeout }

      it 'returns an unavailable error' do
        expect(get.error).to eq(:unavailable)
      end

      it 'retries once before giving up' do
        get

        expect(a_request(:get, endpoint)).to have_been_made.twice
      end
    end

    context 'when the upstream takes too long to answer' do
      before { stub_request(:get, endpoint).to_raise(Net::ReadTimeout) }

      it 'returns an unavailable error' do
        expect(get.error).to eq(:unavailable)
      end
    end

    context 'when the DNS resolution fails' do
      before { stub_request(:get, endpoint).to_raise(SocketError.new('getaddrinfo: nodename nor servname provided')) }

      it 'returns an unavailable error' do
        expect(get.error).to eq(:unavailable)
      end
    end

    context 'when the upstream returns 5xx' do
      before { stub_request(:get, endpoint).to_return(status: 503, body: 'Service Unavailable') }

      it { is_expected.not_to be_success }

      it 'returns an unavailable error' do
        expect(get.error).to eq(:unavailable)
      end

      it 'retries once before giving up' do
        get

        expect(a_request(:get, endpoint)).to have_been_made.twice
      end
    end

    context 'when the upstream recovers after a 5xx' do
      before do
        stub_request(:get, endpoint)
          .to_return(status: 502, body: 'Bad Gateway')
          .then
          .to_return(status: 200, body: '{"foo":"bar"}', headers: json_headers)
      end

      it 'returns the body from the second attempt' do
        expect(get.body).to eq('foo' => 'bar')
      end
    end

    context 'when the upstream rate limits us' do
      before do
        stub_request(:get, endpoint)
          .to_return(status: 429, body: 'Too Many Requests', headers: { 'Retry-After' => '60' })
      end

      it 'returns a rate limited error' do
        expect(get.error).to eq(:rate_limited)
      end

      it 'does not wait for the Retry-After' do
        get

        expect(a_request(:get, endpoint)).to have_been_made.once
      end
    end

    context 'when the upstream returns 4xx' do
      before { stub_request(:get, endpoint).to_return(status: 400, body: '{"error":"bad"}', headers: json_headers) }

      it 'returns an invalid response error without retrying' do
        expect(get.error).to eq(:invalid_response)
        expect(a_request(:get, endpoint)).to have_been_made.once
      end
    end

    context 'when the body is not a valid JSON' do
      before { stub_request(:get, endpoint).to_return(status: 200, body: '<html>oops', headers: json_headers) }

      it 'returns an invalid response error' do
        expect(get.error).to eq(:invalid_response)
      end
    end
  end
end
