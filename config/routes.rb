Rails.application.routes.draw do
  root "home#index"

  get "/auth/hack_club", to: "sessions#new", as: :login
  get "/auth/hack_club/callback", to: "sessions#callback", as: :oauth_callback
  delete "/logout", to: "sessions#destroy", as: :logout

  resource :nda_signature, only: %i[show create] do
    post :resend_cosigner_invite
    delete :retry
  end
  resource :legacy_nda_import, only: %i[show create] do
    post :challenge
    post :lookup
    post :lookup_email
  end

  get "/cosign/:token", to: "cosignatures#show", as: :cosign
  post "/cosign/:token", to: "cosignatures#create"

  namespace :admin do
    root "dashboard#index"
    resources :nda_signatures, only: %i[update destroy] do
      post :sync, on: :member
    end
    resources :users, only: [] do
      post :reset_nda, on: :member
      post :require_current_nda, on: :member
    end
    resources :legacy_nda_imports, only: %i[index update]
  end

  get "/openapi.json", to: "api/v1/docs#openapi", as: :openapi

  namespace :api do
    namespace :v1 do
      get "docs", to: "docs#index", as: :docs
      get "nda_status/:slack_id", to: "nda_statuses#show", as: :nda_status
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
