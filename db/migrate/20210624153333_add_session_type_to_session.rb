class AddSessionTypeToSession < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :session_type, :string
  end
end
