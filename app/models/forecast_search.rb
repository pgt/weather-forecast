# frozen_string_literal: true

class ForecastSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  ADDRESS_MAX_LENGTH = 200

  attribute :address, :string
  attribute :unit, :string, default: Forecast::Formatter::DEFAULT_UNIT

  validates :address, presence: true, length: { maximum: ADDRESS_MAX_LENGTH }
  validates :unit, inclusion: { in: Forecast::Formatter::UNITS }
end
