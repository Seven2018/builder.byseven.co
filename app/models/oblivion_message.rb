class OblivionMessage < ApplicationRecord
  belongs_to :oblivion
  belongs_to :theory, optional: true
end
