Rails.application.routes.draw do
  root "lookups#new"

  get "lookup", to: "lookups#show", as: :lookup

  # Health check for load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
