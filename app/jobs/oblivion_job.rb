class OblivionJob < ApplicationJob
  include SuckerPunch::Job

  def perform
    Session.where(date: Date.today + 2.days).each do |session|
      session.users.each do |user|
        TrainerNotificationMailer.with(user: user).trainer_session_reminder(session, user).deliver
      end
    end
    Training.all.select{|training| training.end_time == (Date.today - 1.days || Date.today - 7.days || Date.today - 1.months || Date.today - 6.months)}.uniq.each do |training|
      attendees = []
      training.sessions.each do |session|
        attendees << session.attendees
      end
      attendees.flatten.uniq.each do |attendee|
        OblivionMailer.with(user: attendee).oblivion_mail(training, attendee).deliver
      end
    end
  end
end
