# frozen_string_literal: true

class ExampleProperties
  def initialize(example)
    @example = example
  end

  def cassette_name
    example
      .metadata[:full_description]
      .strip
      .underscore
      .tr('#', '/')
      .tr(' ', '_')
  end

  def name
    example.metadata[:cassette] || cassette_name
  end

  def record
    default_record = VCR.configuration.default_cassette_options[:record]

    example.metadata[:record] || default_record
  end

  def match_on
    default_match_on = VCR.configuration.default_cassette_options[:match_requests_on]

    example.metadata[:match_requests_on] || default_match_on
  end

  private

  attr_reader :example
end

def handle_vcr(example)
  return run_with_http_interaction(&example) if ENV['VCR_OFF']

  property = ExampleProperties.new(example)

  VCR.use_cassette(
    property.name,
    record: property.record,
    match_requests_on: property.match_on,
    &example
  )
end

# Turn it off the VCR in each HTTP interaction
def run_with_http_interaction(&)
  WebMock.allow_net_connect!
  VCR.turned_off(&).tap do
    WebMock.disable_net_connect!
  end
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock

  c.allow_http_connections_when_no_cassette = true

  c.default_cassette_options = {
    record: :once,
    match_requests_on: %i[method uri]
  }
end
