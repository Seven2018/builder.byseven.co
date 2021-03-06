class Session < ApplicationRecord
  belongs_to :training
  has_many :workshops, -> { order(position: :asc) }, dependent: :destroy
  has_many :session_trainers, dependent: :destroy
  has_many :users, through: :session_trainers
  has_many :session_attendees, dependent: :destroy
  has_many :attendees, through: :session_attendees
  has_many :comments, dependent: :destroy
  has_many :session_forms, dependent: :destroy
  has_many :forms, through: :session_forms
  has_many :attendee_interests, dependent: :destroy
  has_one :oblivion, dependent: :destroy
  validates :title, :duration, presence: true
  validates :session_type, inclusion: { in: [ 'Face-to-face', 'Online' ] }
  accepts_nested_attributes_for :session_trainers
  default_scope { order(:date, :start_time) }

  def title_date
    "#{self.title} - #{self.date&.strftime('%d/%m/%y')}"
  end

  def self.send_reminders
    Session.where(date: Date.today + 2.days).each do |session|
      session.users.each do |user|
        TrainerNotificationMailer.with(user: user).trainer_session_reminder(session, user).deliver_now
      end
    end
  end

  def final_session_attendee_list
    self.attendees.each do |attendee|
      # Training.joins(sessions: :session_attendees).where()
    end
  end
end
