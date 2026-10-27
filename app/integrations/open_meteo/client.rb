# frozen_string_literal: true

module OpenMeteo
  class Client
    DEFAULT_URL = 'https://api.open-meteo.com'
    private_constant :DEFAULT_URL

    def create
      @create ||= HttpClient.new(url: ENV.fetch('OPEN_METEO_URL', DEFAULT_URL))
    end
  end
end
