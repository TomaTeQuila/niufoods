Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "restaurants", to: "restaurants#index"
      post "restaurants", to: "restaurants#create"
      get "restaurants/:id", to: "restaurants#show"
      put "restaurants/:id", to: "restaurants#update"
      delete "restaurants/:id", to: "restaurants#destroy"

      get "products", to: "products#index"
      post "products", to: "products#create"
      get "products/:id", to: "products#show"
      put "products/:id", to: "products#update"
      delete "products/:id", to: "products#destroy"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
