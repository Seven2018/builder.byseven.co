class AddPositionToOblivionMessage < ActiveRecord::Migration[6.0]
  def change
    add_column :oblivion_messages, :position, :integer
    add_column :oblivion_messages, :status, :string, :default => ''
  end
end
