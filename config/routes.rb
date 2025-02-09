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

  # Authentication
  get "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  delete "sign_out", to: "sessions#destroy"
  get "sessions", to: "sessions#index"

  # Registration
  get "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resource :password, only: [ :new, :create, :edit, :update ]
  resource :profile, only: [ :edit, :update ], controller: "users"
  get "up", to: "rails/health#show", as: :rails_health_check

  namespace :admin do
    root to: "applications#index"

    resources :applications do
      collection do
        post :batch_approve
        post :batch_reject
        get  :search
        get  :filter
        get  :dashboard
      end

      member do
        post :request_documents
        post :review_proof  # if you’re handling via standard POST or GET
        post :update_proof_status
        patch :approve
        patch :reject
        post :assign_evaluator
        post :schedule_training
        post :complete_training
        patch :update_proof_status
        patch :update_certification_status
        post :resend_medical_certification
      end
    end

    resources :constituents_dashboard, only: [ :index, :show ]
    resources :appointments_dashboard, only: [ :index, :show ]

    resources :proof_reviews, only: [ :index, :show, :new, :create ]
    resources :proofs, only: [ :new, :create ] do
      post :resubmit, on: :collection
    end

    resources :policies, only: [ :index, :show, :edit, :update ] do
      collection do
        get :changes
        patch :update
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
        patch :update_capabilities
        get :history
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
    resource :dashboard, only: [ :show ], controller: :dashboards
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
    resource :dashboard, only: [ :show ]
    resources :applications do
      member do
        patch :upload_documents
        post :request_review
        get :verify
        patch :submit
        post :resubmit_proof
      end
    end
    resources :appointments, only: [ :index, :show ]
    resources :evaluations, only: [ :index, :show ]
    resources :devices, only: [ :index, :show ]
  end

  namespace :webhooks do
    resources :email_events, only: [ :create ]
    resources :medical_certifications, only: [ :create ]
  end
end
