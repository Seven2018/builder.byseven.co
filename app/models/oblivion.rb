class Oblivion < ApplicationRecord
  belongs_to :session, optional: true
  has_many :oblivion_messages
end
