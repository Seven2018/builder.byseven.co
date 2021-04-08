class CreateOblivions < ActiveRecord::Migration[6.0]
  def change
    create_table :oblivions do |t|
      t.string :title
      t.references :session, foreign_key: true

      t.timestamps
    end
  end
end
