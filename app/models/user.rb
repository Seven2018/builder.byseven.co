class User < ApplicationRecord
  include Users::Access
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :recoverable, :rememberable, :validatable
  devise :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :training_ownerships, dependent: :destroy
  has_many :trainings, through: :training_ownerships
  has_many :session_trainers, dependent: :destroy
  has_many :sessions, through: :session_trainers
  has_many :workshop_modules
  has_many :comments
  belongs_to :client_company, optional: true
  validates :firstname, :lastname, :email, presence: true
  validates_uniqueness_of :email
  validates :access_level, inclusion: { in: ['sevener', 'sevener+', 'training manager', 'admin', 'super_admin'] }

  scope :active, -> {         where(status: :active) }
  scope :inactive, -> {       where(status: :inactive) }

  require 'uri'
  require 'net/http'

  enum status: {
    inactive: 0,
    active: 1
  }

  paginates_per 25


  ###############
  ## PG_SEARCH ##
  ###############

  include PgSearch::Model
  pg_search_scope :search_users,
    against: [ :firstname, :lastname, :email ],
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents


  #############
  ## METHODS ##
  #############

  def fullname
    "#{lastname.upcase} #{firstname.capitalize}"
  end

  def initials
    user = OverviewUser.all(filter: "{Builder_id} = '#{self.id}'").first
    user['Tag']
  end

  def super_admin?
    self.access_level == 'super_admin'
  end

  def is_email_valid?
      (self.email =~ /^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$/).present?
  end

  def hours(training)
    Session.joins(:session_trainers).where(session_trainers: {session_id: training.sessions.ids, user_id: self.id}).map(&:duration).sum
  end

  def hours_this_week(date)
    Session.joins(:session_trainers).where(date: date.beginning_of_week..date.end_of_week, session_trainers: {user_id: self.id}).map(&:duration).sum
  end

  def export_airtable_user
    existing_user = OverviewUser.all.select{|x| x['Builder_id'] == self.id || x['Email'] == self.email}&.first

    if existing_user.present?
      existing_user['Firstname'] = self.firstname
      existing_user['Lastname'] = self.lastname
      existing_user['Email'] = self.email
      existing_user['Builder_id'] = self.id
    else
      existing_user = OverviewUser.create('Firstname' => self.firstname, 'Lastname' => self.lastname, 'Email' => self.email, 'Builder_id' => self.id)
    end

    ['sevener+', 'sevener'].include?(self.access_level) ? existing_user['Status'] = "Sevener" : existing_user['Status'] = "SEVEN"

    existing_user.save
  end

  def self.report
    UpdateBizdevReportJob.perform_now
  end

  def to_builder
    Jbuilder.new do |user|
      user.(self, :firstname, :id)
    end
  end

  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data['email']).first

    # Uncomment the section below if you want users to be created if they don't exist
    # unless user
    #     user = User.create(name: data['name'],
    #        email: data['email'],
    #        password: Devise.friendly_token[0,20]
    #     )
    # end
    user
  end


  ##############
  ## PASSWORD ##
  ##############

  def reset_password!
    self.send(:set_reset_password_token)

    UserMailer.with(user: self)
        .reset_password(self)
        .deliver_later
  end
end
