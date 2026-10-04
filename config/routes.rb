Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :boletas, only: [:index, :new, :create, :show, :edit, :update]
  root "boletas#index"
end