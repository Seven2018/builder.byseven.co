class UserMailer < ApplicationMailer
	default from: CompanyInfo.no_reply

	def reset_password(user)
    @user = user
    @token = user.reset_password_token
    @title = "Hello, #{@user.fullname}"
    @description = "It seems you have forgotten your password for Builder,\n please click the following link to reset it."
    @button_text = "Reset my password"
    # puts accept_user_invitation_url(@user, invitation_token: @token, reset_password: true)
    @button_link = email_redirect_to_front(
      "/auth/reset_password?reset_password_token=#{@token}"
    )
    @nb = "If you have not requested a password reset, please ignore this email."

    mail(to: @user.email, subject: 'Reset your password') do |format|
      format.html { render layout: 'basic_mailer' }
    end
  end
end
