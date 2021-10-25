class Content < ApplicationRecord
  belongs_to :theme, optional: true
  has_many :theory_contents, :dependent => :destroy
  has_many :theories, through: :theory_contents
  has_many :content_modules, :dependent => :destroy
  validates :title, presence: true, allow_blank: false
  before_save :default_values

  # SEARCHING CONTENT BY title
  include PgSearch::Model
  pg_search_scope :search_by_title,
    against: [ :title ],
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents

  def to_builder
    Jbuilder.new do |content|
      content.(self, :title, :id)
    end
  end

  private

  def default_values
    self.duration ||= 0 if self.duration.nil?
  end


  def actions
    return Action.where(id: [self.action1_id, self.action2_id])
  end
end
