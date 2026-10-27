# frozen_string_literal: true

module Nominatim
  class Client
    DEFAULT_URL = 'https://nominatim.openstreetmap.org'
    DEFAULT_USER_AGENT = 'weather-forecast/1.0'

    private_constant :DEFAULT_URL, :DEFAULT_USER_AGENT

    def create
      @create ||= HttpClient.new(url: url, headers: { 'User-Agent' => user_agent })
    end

    private

    def url
      ENV.fetch('NOMINATIM_URL', DEFAULT_URL)
    end

    def user_agent
      ENV.fetch('NOMINATIM_USER_AGENT', DEFAULT_USER_AGENT)
    end
  end
end
