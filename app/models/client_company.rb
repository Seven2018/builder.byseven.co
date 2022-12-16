class ClientCompany < ApplicationRecord
  has_many :client_contacts, dependent: :destroy
  has_many :invoice_items
  has_many :attendees, dependent: :destroy
  # has_one :children, class_name: "ClientCompany", foreign_key: "opco_id"
  belongs_to :opco, class_name: "ClientCompany", optional: true
  validates :client_company_type, inclusion: { in: %w(Company School OPCO) }

  paginates_per 25


  ###############
  ## PG_SEARCH ##
  ###############

  include PgSearch::Model
  pg_search_scope :search_companies,
    against: [ :name ],
    associated_against: {
      client_contacts: [:name, :email],
    },
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents


  #############
  ## METHODS ##
  #############

  def to_builder
    Jbuilder.new do |client_company|
      client_company.(self, :name, :id)
    end
  end

  def trainings_for_copy
    array = []
    self.client_contacts.each do |contact|
      array << contact.trainings
    end
    array = array.flatten(1).sort_by{ |x| x.title }
    array.map do |training|
      training.title + ' : ' + training.refid
    end
    array
  end
end
