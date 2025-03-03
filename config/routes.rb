Rails.application.routes.draw do
  # Test routes (only in test environment)
  if Rails.env.test?
    get "test/auth_status", to: "test#auth_status"
  end
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

    resources :paper_applications, only: [ :new, :create ] do
      collection do
        post :send_rejection_notification
        get :fpl_thresholds
      end
    end

    resources :applications do
      collection do
        post :batch_approve
        post :batch_reject
        get  :search
        get  :filter
        get  :dashboard
      end

      member do
        post :assign_voucher
        post :request_documents
        post :review_proof  # if you're handling via standard POST or GET
        post :update_proof_status
        patch :approve
        patch :reject
        post :assign_evaluator
        post :assign_trainer
        post :schedule_training
        post :complete_training
        patch :update_proof_status
        patch :update_certification_status
        post :resend_medical_certification
      end

      resources :notes, only: [ :create ], controller: "application_notes"
    end

    resources :constituents_dashboard, only: [ :index, :show ]
    resources :appointments_dashboard, only: [ :index, :show ]

    resources :proof_reviews, only: [ :index, :show, :new, :create ]
    resources :proofs, only: [ :new, :create ] do
      post :resubmit, on: :collection
    end

    resources :policies, only: [ :index, :show, :edit, :update, :create ] do
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

    resources :vendors do
      resources :w9_reviews, only: [ :index, :show, :new, :create ]
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

    resources :vouchers do
      member do
        patch :cancel
      end
      collection do
        get :expired
        get :expiring_soon
      end
    end

    resources :invoices do
      member do
        patch :approve
        patch :cancel
      end
      collection do
        get :paid
        get :export_batch
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
    resource :dashboard, only: [ :show ], controller: :dashboard
    # IMPORTANT: The controller must be explicitly specified as :profiles
    # Without this, Rails looks for Vendor::ProfilesController (plural) but the actual controller is Vendor::ProfilesController (singular)
    # This has caused 404 errors in the past when vendors try to access their profile page
    resource :profile, only: [ :edit, :update ], controller: :profiles
    resources :redemptions, only: [ :new, :create ] do
      collection do
        get :check_voucher
        get :verify
      end
    end
    resources :transactions, only: [ :index ] do
      get :report, on: :collection
    end
    resources :invoices, only: [ :index, :show ]
  end

  # Original constituent namespace (will be deprecated)
  # Direct routing to new controllers instead of redirects
  get "/constituent/applications/:id/proofs/resubmit", to: "constituent_portal/proofs/proofs#new"
  post "/constituent/applications/:id/proofs/resubmit", to: "constituent_portal/proofs/proofs#resubmit"
  # Keep these redirects for now
  get "/constituent/applications/:id", to: redirect("/constituent_portal/applications/%{id}")
  get "/constituent/dashboard", to: redirect("/constituent_portal/dashboard")

  namespace :constituent do
    resource :dashboard, only: [ :show ]
    resources :applications do
      member do
        patch :upload_documents
        post :request_review
        get :verify
        patch :submit
        post :resubmit_proof
        namespace :proofs do
          get "new/:proof_type", to: "proofs#new", as: :new_proof
          post "resubmit", to: "proofs#resubmit"
          post "direct_upload", to: "proofs#direct_upload", as: :direct_upload_proof
        end
      end
    end
    resources :appointments, only: [ :index, :show ]
    resources :evaluations, only: [ :index, :show ]
    resources :devices, only: [ :index, :show ]
  end

  # New constituent_portal namespace (replacing constituent)
  namespace :constituent_portal do
    resource :dashboard, only: [ :show ]
    resources :applications, path: "applications" do
      collection do
        get :fpl_thresholds
      end

      member do
        patch :upload_documents
        post :request_review
        get :verify
        patch :submit
        post :resubmit_proof
        post :request_training
        # Define the route with a custom name
        get "proofs/new/:proof_type", to: "proofs/proofs#new", as: :new_proof
        post "proofs/resubmit", to: "proofs/proofs#resubmit", as: :resubmit_proof_document
        post "proofs/direct_upload", to: "proofs/proofs#direct_upload", as: :direct_upload_proof
      end
    end
    resources :appointments, only: [ :index, :show ]
    resources :evaluations, only: [ :index, :show ]
    resources :products, only: [ :index, :show ]

    # Redirect old devices routes to products
    get "/devices", to: redirect("/constituent_portal/products")
    get "/devices/:id", to: redirect("/constituent_portal/products/%{id}")
  end

  namespace :webhooks do
    resources :email_events, only: [ :create ]
    resources :medical_certifications, only: [ :create ]
  end
end
