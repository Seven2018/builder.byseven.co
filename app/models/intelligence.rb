class Intelligence < ApplicationRecord
  has_many :actions
  validates :name, uniqueness: true
  validates :name, :description, presence: true, allow_blank: false
end
