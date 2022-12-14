Rails.application.routes.draw do

  ###########
  # ACTIONS #
  ###########

  resources :actions


  ############
  # AIRTABLE #
  ############

  get :import_airtable, controller: :pages
  get :account_invoice, controller: :pages
  get 'trainings/:id/export_airtable', to: 'pages#export_airtable', as: 'export_airtable'


  #############
  # ATTENDEES #
  #############

  resources :attendees, only: [:index, :show, :new, :create]
  get :import_attendees_form, controller: :attendees
  post :import_attendees, controller: :attendees
  get 'attendees/template_csv', to: 'attendees#template_csv', as: 'template_csv_attendees'
  get 'training/:training_id/session/:id/attendees/export.csv', to: 'attendees#export', as: 'export_attendees'
  # post 'attendees/import', to: 'attendees#import', as: 'import_attendees'


  ######################
  # ATTENDEE_INTERESTS #
  ######################

  post 'new_attendee_interest', to: 'attendee_interests#create', as: 'new_attendee_interest'
  delete 'delete_attendee_interest', to: 'attendee_interests#destroy', as: 'destroy_attendee_interest'


  ####################
  # CLIENT_COMPANIES #
  ####################

  resources :client_companies, path: '/companies' do
    resources :client_contacts, path: '/contacts'
    get :new_attendees, controller: :client_companies
    get :create_attendees, controller: :client_companies
  end
  get :client_companies_search, controller: :client_companies


  ############
  # CONTENTS #
  ############

  resources :contents, only: [:index, :show, :new, :create, :update, :destroy] do
    resources :content_modules, only: [:show, :new, :create, :edit, :update, :destroy]
      get 'content_module/:id/move_up', to: 'content_modules#move_up', as: 'move_up_content_module'
      get 'content_module/:id/move_down', to: 'content_modules#move_down', as: 'move_down_content_module'
    get :manage_linked_theories, controller: :theory_contents
    get :remove_linked_theory, controller: :theory_contents
  end
  get :contents_search, controller: :contents


  #########
  # FORMS #
  #########

  resources :session_forms, only: [:create, :destroy]


  #################
  # INVOICE_ITEMS #
  #################

  resources :invoice_items, only: [:index, :show, :update, :destroy]
  get :report, controller: :invoice_items
  post :new_invoice_item, controller: :invoice_items
  post :new_estimate, controller: :invoice_items
  post :new_airtable_invoice_item, controller: :invoice_items
  post :new_airtable_invoice_item_by_trainer, controller: :invoice_items
  post :new_airtable_invoice_item_by_attendee, controller: :invoice_items
  get :send_invoice_mail, controller: :invoice_items
  get 'invoice_item/:id/copy', to: 'invoice_items#copy', as: 'copy_invoice_item'
  get 'invoice_item/:id/transform_to_invoice', to: 'invoice_items#transform_to_invoice', as: 'transform_to_invoice'
  get 'invoice_item/:id/edit_client', to: 'invoice_items#edit_client', as: 'edit_client_invoice_item'
  get 'invoice_item/:id/credit', to: 'invoice_items#credit', as: 'credit_invoice_item'
  get 'invoice_items/:id/marked_as_send', to: 'invoice_items#marked_as_send', as: 'marked_as_send_invoice_item'
  get 'invoice_items/:id/marked_as_paid', to: 'invoice_items#marked_as_paid', as: 'marked_as_paid_invoice_item'
  get 'invoice_items/:id/marked_as_cancelled', to: 'invoice_items#marked_as_cancelled', as: 'marked_as_cancelled_invoice_item'

  get :airtable_update_invoice, controller: :invoice_items


  #################
  # INVOICE_LINES #
  #################

  resources :invoice_lines, only: [:create, :edit, :update, :destroy]
  get 'invoice_line/:id/move_up', to: 'invoice_lines#move_up', as: 'move_up_invoice_line'
  get 'invoice_line/:id/move_down', to: 'invoice_lines#move_down', as: 'move_down_invoice_line'

  # LINKEDIN (NOT USED)
  # get '/linkedin_scrape', to: 'users#linkedin_scrape', as: 'linkedin_scrape'
  # get '/linkedin_scrape_callback', to: 'users#linkedin_scrape_callback', as: 'linkedin_scrape_callback'
  # devise_scope :user do
  #   get '/users/auth/linkedin/callback', to: 'users/omniauth_callbacks#linkedin', as: 'linkedin_auth'
  # end


  #########
  # PAGES #
  #########

  root to: 'pages#home'
  get :contact_form, controller: :pages
  get :contact_form_becos, controller: :pages
  get :billing, controller: :pages
  get :billing_completed, controller: :pages
  get :export_numbers_activity_cumulation, controller: :pages


  #####################
  # SESSION_ATTENDEES #
  #####################

  post 'session/:id/session_attendees/link_attendees', to: 'session_attendees#link_attendees', as: 'link_attendees'
  post 'training/:id/session_attendees/link_attendees', to: 'session_attendees#link_attendees_to_training', as: 'link_attendees_to_training'
  post 'training/:id/import_for_training', to: 'session_attendees#import_for_training', as: 'import_for_training'
  post 'training/:id/attendee_create_all', to: 'session_attendees#create_all', as: 'attendee_create_all'


  ####################
  # SESSION_TRAINERS #
  ####################

  get :redirect, controller: :session_trainers
  get :calendars, controller: :session_trainers
  get :link_to_session, controller: :session_trainers, as: :trainers_link_to_session
  get :link_to_training, controller: :session_trainers, as: :trainers_link_to_training
  get :remove_session_trainers, controller: :session_trainers
  get :remove_training_trainers, controller: :session_trainers


  ############
  # THEORIES #
  ############

  resources :theories
  get :theories_search, controller: :theories


  #############
  # TRAININGS #
  #############

  resources :trainings do
    get 'sessions_viewer/:id', to: 'sessions#viewer', as: 'session_viewer'
    get 'sessions/:id/copy', to: 'sessions#copy', as: 'copy_session'
    get 'sessions/:id/copy_content', to: 'sessions#copy_content', as: 'copy_content_session'
    get 'sessions/:id/copy_form', to: 'sessions#copy_form', as: 'copy_form_session'
    get 'sessions/:id/presence_sheet', to: 'sessions#presence_sheet', as: 'session_presence_sheet'
    patch 'sessions/:id/update_ajax', to: 'sessions#update_ajax', as: 'update_ajax_session'
    get 'sessions/:id/import_attendees', to: 'sessions#import_attendees', as: 'import_attendees_session'
    resources :sessions, only: [:new, :show, :create, :update, :destroy] do
      post 'workshops/:id', to: 'workshops#move', as: 'move_workshop'
      get 'workshops/:id/save', to: 'workshops#save', as: 'save_workshop'
      get 'workshops_viewer/:id', to: 'workshops#viewer', as: 'workshop_viewer'
      get 'workshops/:id/move_up', to: 'workshops#move_up', as: 'move_up_workshop'
      get 'workshops/:id/move_down', to: 'workshops#move_down', as: 'move_down_workshop'
      get 'workshops/:id/copy_form', to: 'workshops#copy_form', as: 'copy_form_workshop'
      get 'workshops/:id/copy', to: 'workshops#copy', as: 'copy_workshop'
      resources :workshops, only: [:show, :create, :edit, :update, :destroy] do
        resources :workshop_modules, only: [:show, :new, :create, :edit, :update, :destroy]
        get 'workshop_modules_viewer/:id', to: 'workshop_modules#viewer', as: 'workshop_module_viewer'
        get 'workshop_modules/:id/move_up', to: 'workshop_modules#move_up', as: 'move_up_workshop_module'
        get 'workshop_modules/:id/move_down', to: 'workshop_modules#move_down', as: 'move_down_workshop_module'
        get 'workshop_modules/:id/copy_form', to: 'workshop_modules#copy_form', as: 'copy_form_workshop_module'
        get 'workshop_modules/:id/copy', to: 'workshop_modules#copy', as: 'copy_workshop_module'
        resources :theory_workshops, only: [:create, :destroy]
        get :manage_linked_theories, controller: :theory_workshops
        get :remove_linked_theory, controller: :theory_workshops
      end
      resources :session_attendees, only: [:create, :destroy]
      resources :comments, only: [:create, :destroy]
    end
    resources :training_ownerships, only: [:create, :destroy]
    resources :forms, only: [:index, :show, :create, :update, :destroy]

    # OBLIVIONS
    resources :oblivions do
      resources :oblivion_messages
      get :create_oblivion_message, controller: :oblivion_messages
      get :update_oblivion_message, controller: :oblivion_messages
    end
    get :create_oblivion, controller: :oblivions
  end
  get :trainings_search, controller: :trainings
  get 'trainings_completed', to: 'trainings#index_completed', as: 'index_completed'
  get 'trainings_upcoming', to: 'trainings#index_upcoming', as: 'index_upcoming'
  get 'trainings/:id/copy', to: 'trainings#copy', as: 'copy_training'
  get 'training/redirect_docusign', to: 'trainings#redirect_docusign', as: 'redirect_docusign'
  get 'trainings/:id/invoice_form', to: 'trainings#invoice_form', as: 'invoice_form'
  get 'trainings/:id/update_calendar', to: 'session_trainers#update_calendar', as: 'update_calendar'
  get 'trainings/:id/trainer_notification_email', to: 'trainings#trainer_notification_email', as: 'trainer_notification_email'
  get 'trainings/:id/trainer_session_reminder', to: 'trainings#trainer_reminder_email', as: 'trainer_reminder_email'
  get 'show_session_content', to: 'trainings#show_session_content', as: 'show_session_content'
  # get 'trainings/:id/import_attendees', to: 'trainings#import_attendees', as: 'import_attendees_training'
  get :airtable_create_training, controller: :trainings
  get :export_training_to_airtable, controller: :trainings
  get :training_sessions_list, controller: :trainings
  get :sessions_search, controller: :sessions
  get :session_content_search, controller: :sessions


  #########
  # USERS #
  #########

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    passwords: 'users/passwords'
  }

  resources :users
  post :reset_password, controller: :users
  get :users_search, controller: :users
  get :airtable_create_user, controller: :users

  resources :impersonations, only: [:index] do
    post :impersonate, on: :member
    post :stop_impersonating, on: :collection
  end


  #####################
  # OBLIVION_CONTENTS #
  #####################

  resources :oblivion_contents
end
