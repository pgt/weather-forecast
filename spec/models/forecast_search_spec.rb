# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ForecastSearch do
  subject(:search) { described_class.new(address: address, unit: unit) }

  let(:address) { '1600 Amphitheatre Parkway' }
  let(:unit) { 'celsius' }

  it { is_expected.to be_valid }

  it 'uses fahrenheit by default' do
    expect(described_class.new(address: address).unit).to eq('fahrenheit')
  end

  context 'when the address is blank' do
    let(:address) { '  ' }

    it { is_expected.not_to be_valid }
  end

  context 'when the address is too long' do
    let(:address) { 'a' * 201 }

    it { is_expected.not_to be_valid }
  end

  context 'when the unit is not supported' do
    let(:unit) { 'kelvin' }

    it { is_expected.not_to be_valid }
  end
end
