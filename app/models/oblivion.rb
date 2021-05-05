class Oblivion < ApplicationRecord
  belongs_to :session, optional: true
  has_many :oblivion_messages
  accepts_nested_attributes_for :oblivion_messages
end
