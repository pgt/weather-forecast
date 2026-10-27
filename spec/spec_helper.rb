# frozen_string_literal: true

# If SimpleCov starts after your application code is already loaded
# (via require), it won't be able to track your files and their
# coverage! The SimpleCov.start must be issued before any of your
# application code is required!
if ENV['COVERAGE']
  require 'simplecov'

  SimpleCov.start 'rails' do
    enable_coverage :branch
    minimum_coverage line: 95, branch: 85
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.disable_monkey_patching!

  config.order = :random
  Kernel.srand config.seed
end
