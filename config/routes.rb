Rails.application.routes.draw do
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :categories
      resources :certificates
      resources :cities
      resources :clients
      resources :companies
      resources :confirmations
      resources :constants
      resources :countries
      resources :currencies
      resources :dashboard
      resources :emails
      resources :events
      resources :industries
      resources :jobs
      resources :locations
      resources :matching_job_titiles
      resources :omniauth_callbacks
      resources :passwords
      resources :positions
      resources :questions
      resources :degrees
      resources :registrations
      resources :resume_templates
      resources :s3
      resources :schools
      resources :sessions
      resources :sharelinks
      resources :skills
      resources :states
      resources :tags
      resources :talents
      resources :talents_jobs
      resources :templates
      resources :timezones
      resources :vendors
  end
end
end
