# frozen_string_literal: true

class Forecast
  class Day
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :date, :date
    attribute :high, :float
    attribute :low, :float
    attribute :condition, :string

    validates :date, :high, :low, presence: true
  end
end
