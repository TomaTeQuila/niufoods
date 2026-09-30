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

      resources :orders, only: %i[index show create destroy]
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
