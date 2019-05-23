class CreateTheoryContents < ActiveRecord::Migration[5.2]
  def change
    create_table :theory_contents do |t|
      t.references :theory, foreign_key: true
      t.references :content, foreign_key: true

      t.timestamps
    end
  end
end
