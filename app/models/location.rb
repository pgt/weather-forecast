# frozen_string_literal: true

class Location
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :zip_code, :string
  attribute :country_code, :string
  attribute :latitude, :float
  attribute :longitude, :float
  attribute :display_name, :string

  validates :country_code, :latitude, :longitude, presence: true

  def cache_key
    "#{country_code}/#{zip_code}"
  end
end
