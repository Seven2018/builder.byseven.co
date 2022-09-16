class TrainerNotificationMailer < ApplicationMailer
  default from: CompanyInfo.no_reply

  def new_trainer_notification(training, user)
    @training = training
    @sessions = training.sessions.select{|x| x.users.include?(user)}
    @user = user

    mail(to: "#{@user.email}", subject: "#{@training.client_company.name} - #{@training.title} : Récapitulatif intervention")
  end

  def edit_trainer_notification(training, user)
    @training = training
    @sessions = training.sessions.select{|x| x.users.include?(user)}
    @user = user

    mail(to: "#{@user.email}", subject: "#{@training.client_company.name} - #{@training.title} : Récapitulatif intervention (Mise à jour du #{Date.today.strftime('%d/%m/%Y')})")
  end

  def trainer_session_reminder(session, user)
    @training = session.training
    @session = session
    @user = user

    mail(to: "#{@user.email}", subject: "SEVEN : #{@training.title} - Session du #{@session.date.strftime('%d/%m/%Y')}")
  end
end
