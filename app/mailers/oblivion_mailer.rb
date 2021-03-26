class OblivionMailer < ApplicationMailer
  default from: Rails.application.credentials.gmail_username

  def oblivion_mail(training, attendee)
    @training = training
    @attendee = attendee
    mail(to: "#{attendee.email}, brice.chapuis@byseven.co", subject: "Oblivion Test")
  end
end
