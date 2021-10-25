class Theory < ApplicationRecord
  has_many :theory_contents, dependent: :destroy
  has_many :theory_workshops, dependent: :destroy
  has_many :contents, through: :theory_contents
  has_many :workshops, through: :theory_workshops

  # SEARCHING THEORIES BY name
  include PgSearch::Model
  pg_search_scope :search_by_name,
    against: [ :name ],
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents

  def to_builder
    Jbuilder.new do |theory|
      theory.(self, :name, :id)
    end
  end
end
