# frozen_string_literal: true

class Forecast
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :current_temperature, :float
  attribute :feels_like, :float
  attribute :condition, :string
  attribute :timezone, :string
  attribute :fetched_at, :datetime
  attribute :days, default: -> { [] }

  validates :current_temperature, :feels_like, :timezone, :days, presence: true
  validate :all_days_valid

  def today
    days.first
  end

  def format(unit)
    Formatter.new(self, unit: unit)
  end

  private

  def all_days_valid
    errors.add(:days, :invalid) unless days.all?(&:valid?)
  end
end
