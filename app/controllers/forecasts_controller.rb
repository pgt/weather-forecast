# frozen_string_literal: true

class ForecastsController < ApplicationController
  USER_ERRORS = %i[address_not_found zip_code_not_found].freeze
  private_constant :USER_ERRORS

  def show
    @search = ForecastSearch.new(search_params)
    return render_invalid_search unless @search.valid?

    @result = ForecastService.new.execute(@search.address)
    return render_service_error unless @result.success?

    render_forecast
  end

  def new
    @search = ForecastSearch.new
  end

  private

  def search_params
    params.permit(:address, :unit)
  end

  def render_forecast
    @formatter = @result.forecast.format(@search.unit)

    respond_to do |format|
      format.html
      format.json { render json: result_as_json }
    end
  end

  def result_as_json
    {
      address: @search.address,
      cached: @result.cached?,
      location: @result.location.attributes.slice('zip_code', 'country_code', 'display_name', 'latitude', 'longitude'),
      forecast: @formatter.as_json
    }
  end

  def render_invalid_search
    render_error(@search.errors.full_messages.to_sentence, :unprocessable_content)
  end

  def render_service_error
    if USER_ERRORS.include?(@result.error)
      render_error(t(@result.error, scope: 'forecasts.errors'), :unprocessable_content)
    else
      render_error(t('upstream_unavailable', scope: 'forecasts.errors'), :service_unavailable)
    end
  end

  def render_error(message, status)
    @error = message

    respond_to do |format|
      format.html { render :new, status: status }
      format.json { render json: { error: message }, status: status }
    end
  end
end
