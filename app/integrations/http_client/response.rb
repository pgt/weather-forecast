# frozen_string_literal: true

class HttpClient
  class Response
    attr_reader :body, :error

    def initialize(body: nil, error: nil)
      @body = body
      @error = error
    end

    def success?
      error.nil?
    end
  end
end
