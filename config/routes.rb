Rails.application.routes.draw do
  devise_for :users, skip: :registrations
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "health/ready" => "health#show", as: :readiness_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker, defaults: { format: :js }
  get "offline" => "offline#show", as: :offline

  resource :onboarding, only: %i[show update]
  resource :payment_setting, only: %i[show update]
  resources :notifications, only: :index do
    patch :read, on: :member
    patch :read_all, on: :collection
  end
  resources :staff_invitations, only: %i[index create destroy]
  get "staff-invitation/accept", to: "staff_invitation_acceptances#show", as: :accept_staff_invitation
  post "staff-invitation/accept", to: "staff_invitation_acceptances#create", as: :staff_invitation_acceptance

  resources :customers do
    resources :measurement_profiles, only: %i[new create show destroy] do
      resources :measurements, only: %i[new create show]
    end
  end
  resources :measurements, only: :index

  resources :designs, only: %i[index new create show edit update] do
    resource :favourite, controller: "design_favourites", only: %i[create destroy]
    member do
      patch :archive
    end
  end

  resources :design_selections, only: %i[new create update destroy] do
    patch :restore, on: :member
  end
  resources :design_shares, only: %i[index new create show destroy]
  get "s", to: "public/design_shares#show", as: :public_design_share
  post "s/feedback", to: "public/design_shares#feedback", as: :public_design_share_feedback

  resources :design_collections, only: %i[index show new create edit update] do
    patch :set_cover, on: :member
    patch :archive, on: :member
    patch :restore, on: :member
    resources :design_collection_items, only: %i[new create destroy]
  end

  resources :orders, only: %i[index new create show] do
    resources :payments, only: %i[new create]
    resource :delivery, only: %i[new create]
    member do
      patch :confirm
      get :job_card
      get :qr_code, defaults: { format: :svg }
    end
  end
  resources :payments, only: %i[index show] do
    member do
      get :receipt
      patch :void
    end
  end
  resources :deliveries, only: %i[index show] do
    get :receipt, on: :member
  end

  resources :expenses, only: %i[index new create show] do
    get :export, on: :collection, defaults: { format: :csv }
    member do
      get :voucher
      patch :approve
      patch :void
      post :record_next
    end
  end

  resources :reports, only: :index do
    get :export, on: :collection, defaults: { format: :csv }
  end

  resources :staff, controller: "staff", only: %i[index new create show edit update] do
    patch :archive, on: :member
  end
  resources :attendance_records, only: :index do
    post :check_in, on: :collection
    patch :check_out, on: :member
  end
  resources :leave_requests, only: %i[index new create] do
    member do
      patch :approve
      patch :reject
      patch :cancel
    end
  end
  resources :work_shifts, only: %i[index new create] do
    patch :cancel, on: :member
  end

  resources :inventory_items, path: "inventory" do
    patch :archive, on: :member
  end
  resources :stock_movements, only: :create

  get "production", to: "productions#index", as: :production
  resources :production_tasks, only: [] do
    member do
      patch :claim
      patch :assign
      patch :start
      patch :complete
      patch :skip
      patch :reopen
    end
  end

  # Defines the root path route ("/")
  root "dashboard#show"
end
