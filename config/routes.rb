# frozen_string_literal: true

Rails.application.routes.draw do
  root 'forecasts#new'

  resource :forecast, only: %i[new show]

  get 'up' => 'rails/health#show', as: :rails_health_check
end
