# frozen_string_literal: true

module Nominatim
  module Finders
    class Location
      attr_reader :error

      def find(address)
        response = http_client.get('/search', params(address))
        @error = response.error

        return unless response.success?
        return invalid_response unless places?(response.body)
        return address_not_found if response.body.empty?

        location = build_location(response.body.first)

        location.valid? ? location : invalid_response
      end

      private

      def params(address)
        { q: address, format: 'jsonv2', addressdetails: 1, limit: 1 }
      end

      def places?(body)
        body.is_a?(Array) && body.all?(Hash)
      end

      def build_location(place)
        address = place['address'].to_h

        ::Location.new(
          zip_code: normalize_zip_code(address['postcode']),
          country_code: address['country_code'],
          latitude: Float(place['lat'], exception: false),
          longitude: Float(place['lon'], exception: false),
          display_name: place['display_name']
        )
      end

      def normalize_zip_code(postcode)
        zip_code = postcode.to_s.split(/[;,]/).first.to_s.strip

        zip_code.match?(/\A\d{5}-\d{4}\z/) ? zip_code.first(5) : zip_code.presence
      end

      def address_not_found
        @error = :address_not_found
        nil
      end

      def invalid_response
        @error = :invalid_response
        nil
      end

      def http_client
        @http_client ||= Client.new.create
      end
    end
  end
end
