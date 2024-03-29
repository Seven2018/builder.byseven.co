class SessionTrainer < ApplicationRecord
  belongs_to :user
  belongs_to :session
  belongs_to :invoice_item, optional: true
  validates_uniqueness_of :session_id, scope: :user_id
  validates_uniqueness_of :user_id, scope: :session_id
  self.inheritance_column = :_type_disabled
end
