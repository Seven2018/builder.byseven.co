class CreateOblivions < ActiveRecord::Migration[6.0]
  def change
    create_table :oblivions do |t|
      t.string :title
      t.date :date
      t.references :session, foreign_key: true
      t.integer :content1
      t.integer :content2
      t.integer :content3
      t.integer :content4

      t.timestamps
    end
  end
end
