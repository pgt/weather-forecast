# frozen_string_literal: true

source 'https://rubygems.org'

gem 'bootsnap', require: false
gem 'propshaft'
gem 'puma', '>= 5.0'
gem 'rails', '~> 8.1.4'

gem 'faraday', '~> 2.13'
gem 'faraday-retry', '~> 2.3'

gem 'redis', '~> 5.4'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'brakeman', require: false
  gem 'bundler-audit', require: false
  gem 'debug', platforms: %i[mri windows], require: 'debug/prelude'
  gem 'rspec-rails', '~> 8.0'
  gem 'rubocop', require: false # Static analysis of the code
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
end

group :development do
  gem 'web-console'
end

group :test do
  gem 'simplecov', require: false
  gem 'vcr', '~> 6.3'
  gem 'webmock', '~> 3.25'
end
