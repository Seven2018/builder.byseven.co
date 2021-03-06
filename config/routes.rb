Rails.application.routes.draw do
  # get 'session_trainers/new'
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }

  # PAGES
  root to: 'pages#home'
  get 'survey', to: 'pages#survey', as: 'survey'
  get 'numbers_activity', to: 'pages#numbers_activity', as: 'numbers_activity'
  get 'numbers_sales', to: 'pages#numbers_sales', as: 'numbers_sales'
  get 'dashboard_sevener', to: 'pages#dashboard_sevener', as: 'dashboard_sevener'
  get 'contact_form', to: 'pages#contact_form', as: 'contact_form'
  get 'billing', to: 'pages#billing', as: 'billing'
  get :sandbox, controller: :pages
  get 'intel_form', to: 'pages#intel_form', as: 'intel_form'
  get 'intel_subscription', to: 'pages#intel_subscription', as: 'intel_subscription'
  get 'intel_thank_you', to: 'pages#intel_thank_you', as: 'intel_thank_you'
  get 'intel_new_attendee', to: 'pages#intel_new_attendee', as: 'intel_new_attendee'
  post 'intel_create_attendee', to: 'pages#intel_create_attendee', as: 'intel_create_attendee'
  get 'cumulation', to: 'pages#export_numbers_activity_cumulation', as: 'export_numbers_activity_cumulation'

  # AIRTABLE
  get 'airtable_import_users', to: 'pages#airtable_import_users', as: 'airtable_import_users'
  get 'import_airtable', to: 'pages#import_airtable', as: 'import_airtable'
  get 'trainings/:id/export_airtable', to: 'pages#export_airtable', as: 'export_airtable'
  get 'airtable_partners_form', to:'pages#airtable_partners_form', as: 'airtable_partners_form'
  get 'airtable/account_invoice', to: 'pages#account_invoice', as: 'account_invoice'

  # USERS
  resources :users
  # get 'users_search', to: 'users#users_search', as: 'users_search'
  get :users_search, controller: :users
  get :airtable_create_user, controller: :users

  # ACTIONS
  resources :actions

  # THEORIES
  resources :theories

  # CONTENTS
  resources :contents, only: [:index, :show, :new, :create, :update, :destroy] do
    resources :content_modules, only: [:show, :new, :create, :edit, :update, :destroy]
      get 'content_module/:id/move_up', to: 'content_modules#move_up', as: 'move_up_content_module'
      get 'content_module/:id/move_down', to: 'content_modules#move_down', as: 'move_down_content_module'
    get :manage_linked_theories, controller: :theory_contents
    get :remove_linked_theory, controller: :theory_contents
  end

  # CLIENT COMPANIES
  resources :client_companies, path: '/companies' do
    resources :client_contacts, path: '/contacts'
    get 'new_attendees', to: 'client_companies#new_attendees', as: 'new_attendees'
    get 'create_attendees', to: 'client_companies#create_attendees', as: 'create_attendees'
  end

  # INVOICE ITEMS
  resources :invoice_items, only: [:index, :show, :edit, :update, :destroy]
  get 'invoice_item/:id/copy', to: 'invoice_items#copy', as: 'copy_invoice_item'
  get 'invoice_item/:id/transform_to_invoice', to: 'invoice_items#transform_to_invoice', as: 'transform_to_invoice'
  get 'invoice_item/:id/edit_client', to: 'invoice_items#edit_client', as: 'edit_client_invoice_item'
  get 'invoice_item/:id/credit', to: 'invoice_items#credit', as: 'credit_invoice_item'
  get 'invoices', to: 'invoice_items#invoice_index', as: 'invoices'
  post 'new_invoice_item', to: 'invoice_items#new_invoice_item', as: 'new_invoiceitem'
  post 'new_airtable_invoice_item', to: 'invoice_items#new_airtable_invoice_item', as: 'new_airtable_invoiceitem'
  post 'new_airtable_invoice_item_by_trainer', to: 'invoice_items#new_airtable_invoice_item_by_trainer', as: 'new_airtable_invoiceitem_by_trainer'
  post 'new_airtable_invoice_item_by_attendee', to: 'invoice_items#new_airtable_invoice_item_by_attendee', as: 'new_airtable_invoiceitem_by_attendee'
  get 'send_invoice_mail', to: 'invoice_items#send_invoice_mail', as: 'send_invoice_mail'
  post 'new_sevener_invoice', to: 'invoice_items#new_sevener_invoice', as: 'new_sevener_invoice'
  post 'new_estimate', to: 'invoice_items#new_estimate', as: 'new_estimate'
  get 'estimates', to: 'invoice_items#estimate_index', as: 'estimates'
  get 'invoice_items/:id/export', to: 'invoice_items#export', as: 'invoice_item_export'
  get 'invoice_items/:id/marked_as_send', to: 'invoice_items#marked_as_send', as: 'marked_as_send_invoice_item'
  get 'invoice_items/:id/marked_as_paid', to: 'invoice_items#marked_as_paid', as: 'marked_as_paid_invoice_item'
  get 'invoice_items/:id/marked_as_cancelled', to: 'invoice_items#marked_as_cancelled', as: 'marked_as_cancelled_invoice_item'
  get 'invoice_items/export_to_csv', to: 'invoice_items#export_to_csv', as: 'export_to_csv_invoice_items'
  post 'redirect_upload_to_drive', to: 'invoice_items#redirect_upload_to_drive', as: 'redirect_upload_to_drive'
  post 'upload_to_drive', to: 'invoice_items#upload_to_drive', as: 'upload_to_drive'
  post 'upload_to_sheet', to: 'invoice_items#upload_to_sheet', as: 'upload_to_sheet'
  get 'report', to: 'invoice_items#report', as: 'report'
  resources :invoice_lines, only: [:create, :edit, :update, :destroy]
  get 'invoice_line/:id/move_up', to: 'invoice_lines#move_up', as: 'move_up_invoice_line'
  get 'invoice_line/:id/move_down', to: 'invoice_lines#move_down', as: 'move_down_invoice_line'

  # TRAININGS
  resources :trainings do
    get 'sessions_viewer/:id', to: 'sessions#viewer', as: 'session_viewer'
    get 'sessions/:id/copy', to: 'sessions#copy', as: 'copy_session'
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
        resources :workshop_modules
        get 'workshop_modules_viewer/:id', to: 'workshop_modules#viewer', as: 'workshop_module_viewer'
        get 'workshop_modules/:id/move_up', to: 'workshop_modules#move_up', as: 'move_up_workshop_module'
        get 'workshop_modules/:id/move_down', to: 'workshop_modules#move_down', as: 'move_down_workshop_module'
        get 'workshop_modules/:id/copy_form', to: 'workshop_modules#copy_form', as: 'copy_form_workshop_module'
        get 'workshop_modules/:id/copy', to: 'workshop_modules#copy', as: 'copy_workshop_module'
        resources :theory_workshops, only: [:create, :destroy]
        get :manage_linked_theories, controller: :theory_workshops
        get :remove_linked_theory, controller: :theory_workshops
      end
      resources :session_trainers, only: [:create, :destroy]
      resources :session_attendees, only: [:create, :destroy]
      resources :comments, only: [:create, :destroy]
    end
    get 'session_trainers/create_all', to: 'session_trainers#create_all', as: 'create_all_session_trainers'
    resources :training_ownerships, only: [:create, :destroy]
    post 'new_writer', to: 'training_ownerships#new_writer', as: 'new_writer'
    resources :forms, only: [:index, :show, :create, :update, :destroy]

    # OBLIVIONS
    resources :oblivions do
      resources :oblivion_messages
      get :create_oblivion_message, controller: :oblivion_messages
      get :update_oblivion_message, controller: :oblivion_messages
    end
    get :create_oblivion, controller: :oblivions
  end
  get 'trainings_completed', to: 'trainings#index_completed', as: 'index_completed'
  get 'trainings_upcoming', to: 'trainings#index_upcoming', as: 'index_upcoming'
  get 'trainings_week', to: 'trainings#index_week', as: 'index_week'
  get 'trainings_month', to: 'trainings#index_month', as: 'index_month'
  get 'trainings/:id/copy', to: 'trainings#copy', as: 'copy_training'
  get 'training/redirect_docusign', to: 'trainings#redirect_docusign', as: 'redirect_docusign'
  post 'trainings/:id/certificate', to: 'trainings#certificate', as: 'certificate_training'
  post 'trainings/:id/certificate_rs', to: 'trainings#certificate_rs', as: 'certificate_rs_training'
  get 'trainings/:id/invoice_form', to: 'trainings#invoice_form', as: 'invoice_form'
  get 'trainings/:id/update_calendar', to: 'session_trainers#update_calendar', as: 'update_calendar'
  get 'trainings/:id/trainer_notification_email', to: 'trainings#trainer_notification_email', as: 'trainer_notification_email'
  get 'trainings/:id/trainer_session_reminder', to: 'trainings#trainer_reminder_email', as: 'trainer_reminder_email'
  get 'show_session_content', to: 'trainings#show_session_content', as: 'show_session_content'
  # get 'trainings/:id/import_attendees', to: 'trainings#import_attendees', as: 'import_attendees_training'

  # ATTENDEES
  resources :attendees, only: [:index, :show, :new, :create]
  get 'attendees/template_csv', to: 'attendees#template_csv', as: 'template_csv_attendees'
  # post 'attendees/import', to: 'attendees#import', as: 'import_attendees'
  get 'training/:training_id/session/:id/attendees/export.csv', to: 'attendees#export', as: 'export_attendees'
  get 'attendee/new_kea_partners', to: 'attendees#new_kea_partners', as: 'new_kea_partners_attendee'
  post 'attendee/create_kea_partners', to: 'attendees#create_kea_partners', as: 'create_kea_partners_attendee'
  post 'new_session_attendee/kea_partners', to: 'session_attendees#create_kea_partners', as: 'new_kea_partners_session_attendee'
  delete 'delete_session_attendee/kea_partners', to: 'session_attendees#destroy_kea_partners', as: 'destroy_kea_partners_session_attendee'
  get :import_attendees_form, controller: :attendees
  post :import_attendees, controller: :attendees

  # SESSION ATTENDEES
  post 'session/:id/session_attendees/link_attendees', to: 'session_attendees#link_attendees', as: 'link_attendees'
  post 'training/:id/session_attendees/link_attendees', to: 'session_attendees#link_attendees_to_training', as: 'link_attendees_to_training'
  post 'training/:id/import_for_training', to: 'session_attendees#import_for_training', as: 'import_for_training'
  post 'training/:id/attendee_create_all', to: 'session_attendees#create_all', as: 'attendee_create_all'


  # ATTENDEES INTERESTS
  post 'new_attendee_interest', to: 'attendee_interests#create', as: 'new_attendee_interest'
  delete 'delete_attendee_interest', to: 'attendee_interests#destroy', as: 'destroy_attendee_interest'

  # FORMS
  resources :session_forms, only: [:create, :destroy]

  # TRAINERS
  get '/redirect', to: 'session_trainers#redirect', as: 'redirect'
  get '/callback', to: 'session_trainers#callback', as: 'callback'
  get '/calendars', to: 'session_trainers#calendars', as: 'calendars'
  get '/remove_session_trainers', to: 'session_trainers#remove_session_trainers', as: 'remove_session_trainers'
  get '/remove_training_trainers', to: 'session_trainers#remove_training_trainers', as: 'remove_training_trainers'

  # OBLIVION_CONTENTS
  resources :oblivion_contents

  # LINKEDIN
  get '/linkedin_scrape', to: 'users#linkedin_scrape', as: 'linkedin_scrape'
  get '/linkedin_scrape_callback', to: 'users#linkedin_scrape_callback', as: 'linkedin_scrape_callback'
  # devise_scope :user do
  #   get '/users/auth/linkedin/callback', to: 'users/omniauth_callbacks#linkedin', as: 'linkedin_auth'
  # end
end
