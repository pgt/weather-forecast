# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'webmock/rspec'
require 'vcr'

Rails.root.glob('spec/support/**/*.rb').sort.each { |f| require f }

RSpec.configure do |config|
  config.use_active_record = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include ActiveSupport::Testing::TimeHelpers

  config.around(:each, :vcr) { |example| handle_vcr(example) }
end
