Rails.application.routes.draw do
  get 'session_trainers/new'
  devise_for :users
  resources :users
  root to: 'pages#home'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :intelligences
  resources :actions
  resources :contents do
    resources :content_modules
  end
  resources :client_companies, path: '/companies'
  resources :client_contacts, path: '/contacts'
  resources :trainings do
    resources :sessions do
      resources :workshops, only: [:show, :create, :edit, :update, :destroy] do
        resources :workshop_modules
      end
      resources :session_trainers, only: [:create, :destroy], path: '/trainers'
      resources :comments
    end
    resources :training_ownerships, only: [:create, :destroy], path: '/owners'
  end
  get 'trainings_week', to: 'trainings#index_week', as: "index_week"
  get 'trainings_month', to: 'trainings#index_month', as: "index_month"
  post 'workshop/:id', to: "workshops#move", as: "move_workshop"
  get 'workshop/:id', to: 'workshops#save', as: "save_workshop"
  get 'workshop_module/:id/move_up', to: "workshop_modules#move_up", as: "move_up_workshop_module"
  get 'workshop_module/:id/move_down', to: "workshop_modules#move_down", as: "move_down_workshop_module"
end
