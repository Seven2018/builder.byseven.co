class AddAirtableIdToTraining < ActiveRecord::Migration[6.0]
  def change
    add_column :trainings, :airtable_id, :string, default: ""

    Training.all.each do |training|
      airtable_training = OverviewTraining.all(filter: "{Builder_id} = '#{training.id}'")&.first

      if airtable_training.present?
        training.update airtable_id: airtable_training.id
      end
    end
  end
end
