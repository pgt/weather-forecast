# frozen_string_literal: true

class HttpClient
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3

  RETRY_OPTIONS = {
    max: 1,
    interval: 0.3,
    interval_randomness: 0.5,
    backoff_factor: 2,
    max_interval: 1,
    methods: %i[get],
    retry_statuses: [429, 500, 502, 503, 504],
    exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::RetriableResponse]
  }.freeze

  private_constant :OPEN_TIMEOUT, :READ_TIMEOUT, :RETRY_OPTIONS

  attr_reader :url

  def initialize(url:, headers: {}, read_timeout: READ_TIMEOUT)
    @url = url
    @headers = headers
    @read_timeout = read_timeout
  end

  def get(path, params = {})
    response = connection.get(path, params)

    Response.new(body: response.body, error: error_for(response.status))
  rescue Faraday::ParsingError
    Response.new(error: :invalid_response)
  rescue Faraday::Error
    Response.new(error: :unavailable)
  end

  private

  attr_reader :headers, :read_timeout

  def connection
    @connection ||= Faraday.new(url: url, headers: headers, request: timeouts) do |conn|
      conn.request :retry, RETRY_OPTIONS
      conn.response :json, content_type: /\bjson$/

      conn.adapter Faraday.default_adapter
    end
  end

  def timeouts
    { open_timeout: OPEN_TIMEOUT, read_timeout: read_timeout }
  end

  def error_for(status)
    case status
    when 200..299 then nil
    when 429 then :rate_limited
    when 400..499 then :invalid_response
    else :unavailable
    end
  end
end
