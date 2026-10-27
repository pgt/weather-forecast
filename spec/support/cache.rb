# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, :caching) do |example|
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    example.run
  ensure
    Rails.cache = original_cache
  end
end
