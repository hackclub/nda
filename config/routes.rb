Rails.application.routes.draw do
  root "home#index"

  get "/auth/hack_club", to: "sessions#new", as: :login
  get "/auth/hack_club/callback", to: "sessions#callback", as: :oauth_callback
  delete "/logout", to: "sessions#destroy", as: :logout

  resource :nda_signature, only: %i[show create]

  namespace :api do
    namespace :v1 do
      get "nda_status/:slack_id", to: "nda_statuses#show", as: :nda_status
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
