class ApplicationController < ActionController::Base
  include Pundit

  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :controller_action
  # before_action :set_time_zone, if: :user_signed_in?

  impersonates :user

  # Pundit: white-list approach.
  after_action :verify_authorized, except: :index, unless: :skip_pundit?
  after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

  # Uncomment when you *really understand* Pundit!
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  def controller_action
    @controller_action = [controller_name, action_name].join('_').to_sym
  end

  protected

  def after_sign_in_path_for(resource)
    trainings_path
  end

  def after_sign_out_path_for(resource)
    request.referrer
  end

  private

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end

  # def set_time_zone
  #   Time.zone = current_user.time_zone
  # end
end
