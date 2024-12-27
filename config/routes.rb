Rails.application.routes.draw do
  root to: "home#index"

  # Static pages
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "accessibility", to: "pages#accessibility"
  get "help", to: "pages#help", as: :help
  get "how_it_works", to: "pages#how_it_works", as: :how_it_works
  get "eligibility", to: "pages#eligibility", as: :eligibility
  get "apply", to: "pages#apply", as: :apply
  get "contact", to: "pages#contact", as: :contact

  # Authentication routes
  get "sign_in", to: "sessions#new"
  get "login", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy"
  get "sessions", to: "sessions#index"
  delete "sessions/:id", to: "sessions#destroy", as: :session

  # Registration routes
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resource :password, only: [ :edit, :update ]

  # Regular application routes for constituents
  resources :applications, only: [ :new, :create, :show, :edit, :update ]

  namespace :identity do
    resource :email, only: [ :edit, :update ]
    resource :email_verification, only: [ :edit, :create ]
    resource :password_reset, only: [ :new, :edit, :create, :update ]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "dashboard#index"

    resources :constituents_dashboard, only: [ :index, :show ]
    resources :applications_dashboard, only: [ :index, :show ]
    resources :appointments_dashboard, only: [ :index, :show ]
    resource :policies, only: [ :edit, :update ]

    resources :users do
      member do
        post :approve
        post :suspend
        post :reactivate
        post :assign_constituents
        post :remove_constituents
        post :update_availability
        post :deactivate
        post :reset_password
        post :remind_to_complete
        post :assign_evaluator
      end
      collection do
        get :evaluators
        get :vendors
        get :constituents
      end
    end

    resources :applications do
      member do
        patch :verify_income
        patch :request_documents
        patch :approve
        patch :reject
      end

      collection do
        get :search
        get :filter
        patch :batch_approve
        patch :batch_reject
      end
    end

    resources :products do
      member do
        post :archive
        post :unarchive
      end
      collection do
        get :inventory_report
      end
    end

    resources :reports, only: [ :index, :show ] do
      collection do
        get :equipment_distribution
        get :evaluation_metrics
        get :vendor_performance
      end
    end
   end

  namespace :evaluator do
    resource :dashboard, only: [ :show ]
    resources :evaluations do
      member do
        post :submit_report
        post :request_additional_info
      end
      collection do
        get :pending
        get :completed
      end
    end
  end

  namespace :vendor do
    resource :dashboard, only: [ :show ]
  end

  # for constituent routes
  namespace :constituent do
    # Dashboard
    resource :dashboard, only: [ :show ]

    # Applications
    resources :applications, only: [ :index, :show, :new, :create, :edit, :update ] do
      member do
        patch :upload_documents  # For adding documentation
        post :request_review     # Request review after adding docs
      end
    end

    # Appointments
    resources :appointments, only: [ :index, :show ]

    # Evaluations (read-only access for constituents)
    resources :evaluations, only: [ :index, :show ]

    # Devices (products assigned to constituent)
    resources :devices, only: [ :index, :show ]

    # Medical certification status
    resource :medical_certification, only: [ :show ]
  end
end
