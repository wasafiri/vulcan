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
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy"
  get "sessions", to: "sessions#index"

  # Registration routes
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resource :password, only: [ :new, :create, :edit, :update ]
  resource :profile, only: [ :edit, :update ], controller: "users"

  # Health check
  get "up", to: "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "dashboard#index"

    resources :constituents_dashboard, only: [ :index, :show ]
    resources :applications_dashboard, only: [ :index, :show ] do
      member do
        patch :approve
        patch :reject
        post :assign_evaluator
      end
    end
    resources :appointments_dashboard, only: [ :index, :show ]

    resource :policies, only: [ :edit, :update ] do
      collection do
        get :changes
      end
    end

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
        patch :update_role
      end

      collection do
        get :evaluators
        get :vendors
        get :constituents
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


  namespace :evaluators do
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

  namespace :constituent do
    # Dashboard
    resource :dashboard, only: [ :show ]

    # Applications
    resources :applications, only: [ :index, :show, :new, :create, :edit, :update ] do
      member do
        patch :upload_documents
        post :request_review
        get :verify
        patch :submit
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
