require_relative 'boot'

require 'rails/all'
require 'csv'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module BuilderBysevenCo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
    # config.exception_handler = {
    #   dev:        nil, # allows you to turn ExceptionHandler "on" in development
    #   db:         nil, # allocates a "table name" into which exceptions are saved (defaults to nil)
    #   email:      nil, # sends exception emails to a listed email (string // "you@email.com")

    #   # Custom Exceptions
    #   custom_exceptions: {
    #     #'ActionController::RoutingError' => :not_found # => example
    #   },

    #   # On default 5xx error page, social media links included
    #   social: {
    #     facebook: nil, # Facebook page name
    #     twitter:  nil, # Twitter handle
    #     youtube:  nil, # Youtube channel name / ID
    #     linkedin: nil, # LinkedIn name
    #     fusion:   nil  # FL Fusion handle
    #   },

    #   # This is an entirely NEW structure for the "layouts" area
    #   # You're able to define layouts, notifications etc ↴

    #   # All keys interpolated as strings, so you can use symbols, strings or integers where necessary
    #   exceptions: {

    #     :all => {
    #       layout: "exception", # define layout
    #       notification: true # (false by default)
    #       # deliver: #something here to control the type of response
    #     }
    #   }
    # }
    config.session_store :cookie_store, key: '_app_session', expire_after: 7.days

    config.action_mailer.default_url_options = { host: ENV['APP_DOMAIN'] }
    config.action_mailer.delivery_method = :postmark
    config.action_mailer.postmark_settings = { api_token: ENV['POSTMARK_API_TOKEN'] }

    config.active_job.queue_adapter = :sucker_punch

    config.after_initialize do
      ActionText::ContentHelper.allowed_attributes.add 'style'
      ActionText::ContentHelper.allowed_tags.add 'span'
    end
  end
end
