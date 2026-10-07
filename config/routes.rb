Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :boletas
  root "boletas#index"
end
