class ChangeTrainingColumns < ActiveRecord::Migration[6.0]
  def change
    rename_column :trainings, :mode, :training_type
    add_column :content_modules, :format, :string
    add_column :workshop_modules, :format, :string
  end
end
