class Workshop < ApplicationRecord
  belongs_to :session
  belongs_to :theme, optional: true
  has_many :workshop_modules, dependent: :destroy
  has_many :theory_workshops, :dependent => :destroy
  has_many :theories, through: :theory_workshops
  validates :title, presence: true, allow_blank: false
  acts_as_list scope: :session
  before_save :default_values

  include PgSearch::Model
  pg_search_scope :search_by_title_and_content,
    against: [ :title ],
    associated_against: {
      workshop_modules: [:title, :instructions],
    },
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents

  private

  def default_values
    self.duration ||= 0 if self.duration.nil?
  end
end
