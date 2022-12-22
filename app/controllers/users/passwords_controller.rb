# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
  # def create
  #   super
  # end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  def update
    # super
    user = User.find_by(reset_password_token: params.dig(:user, :reset_password_token))

    if user && params.dig(:user, :password) == params.dig(:user, :password_confirmation)
      user.update password: params.dig(:user, :password)
      sign_in user
      redirect_to root_path
    else
      redirect_back(fallback_location: root_path)
    end
  end

  # protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  # The path used after sending reset password instructions
  # def after_sending_reset_password_instructions_path_for(resource_name)
  #   super(resource_name)
  # end
end