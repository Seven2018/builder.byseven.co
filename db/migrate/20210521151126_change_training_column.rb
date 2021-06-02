class ChangeTrainingColumn < ActiveRecord::Migration[6.0]
  def change
    rename_column :trainings, :gdrive_link, :infos
  end
end
