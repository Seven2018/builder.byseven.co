class Attendee < ApplicationRecord
  belongs_to :client_company, optional: true
  has_many :session_attendees, dependent: :destroy
  has_many :sessions, through: :session_attendees
  has_many :attendee_interests, dependent: :destroy
  validates :firstname, :lastname, :email, presence: true
  validates_uniqueness_of :email
  before_save :make_capitalize
  require 'csv'

  def fullname
    "#{firstname} #{lastname}"
  end

  def trainings
    Training.joins(sessions: :session_attendees).where(sessions: {session_attendees: {attendee_id: self.id}})
  end

  def last_session(training)
    session = Session.joins(:session_attendees).where(session_attendees: {session_id: training.sessions.ids, attendee_id: self.id}).sort{|a,b|  a.date <=> b.date}.last
  end


  #######
  # CSV #
  #######

  def self.import(file, client_company_id = nil)
    attendees = []
    CSV.foreach(file.path, headers: true) do |row|
      attendee = Attendee.new(row.to_hash)
      attendee.client_company_id = client_company_id
      if attendee.save
        attendees << attendee
      else
        attendees << Attendee.find_by(email: attendee.email)
      end
    end
    return attendees
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << column_names
      all.each do |result|
        csv << result.attributes.values_at(*column_names)
      end
    end
  end

  def self.to_csv_template
    CSV.generate do |csv|
      column_names = ["firstname", "lastname", "employee_id", "email", "client_company_id"]
      csv << column_names
      all.each do |result|
        csv << result.attributes.values_at(*column_names)
      end
    end
  end

  def make_capitalize
    self.firstname.capitalize!
    self.lastname.upcase!
    self.email.downcase!
  end

  ##########

end
