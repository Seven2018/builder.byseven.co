class UserMailer < ApplicationMailer
	default from: CompanyInfo.no_reply

  def account_created(user)
    @user = user
    @token = user.invitation_token
    @icon = '👋'
    @title = "Hello, #{@user.fullname}"
    @description = "Your have been invited to join Builder !\n Click here to create your password"

    @button_text = "Create my password"
    @button_link = edit_user_password_url(reset_password_token: @token)

    mail(to: @user.email, subject: 'Welcome to Booklet !')
  end

	def reset_password(user)
    @user = user
    @token = user.reset_password_token
    @title = "Hello, #{@user.fullname}"
    @description = "It seems you have forgotten your password for Builder,\n please click the following link to reset it."

    @button_text = "Reset my password"
    @button_link = edit_user_password_url(reset_password_token: @token)

    @nb = "If you have not requested a password reset, please ignore this email."

    mail(to: @user.email, subject: 'Reset your password') do |format|
      format.html { render layout: 'basic_mailer' }
    end
  end
end
