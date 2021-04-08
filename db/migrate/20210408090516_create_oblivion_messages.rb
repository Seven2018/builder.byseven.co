class CreateOblivionMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :oblivion_messages do |t|
      t.string :title
      t.string :content
      t.string :image
      t.references :theory, foreign_key: true
      t.references :oblivion, foreign_key: true

      t.timestamps
    end
  end
end
