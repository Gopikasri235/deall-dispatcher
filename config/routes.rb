require "sidekiq/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Sidekiq Web UI for monitoring
  mount Sidekiq::Web => "/sidekiq"

  # API namespace for analytics service
  namespace :api do
    namespace :v1 do
      # Analytics events endpoint
      # POST /api/v1/analytics
      post "analytics", to: "analytics#create"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
