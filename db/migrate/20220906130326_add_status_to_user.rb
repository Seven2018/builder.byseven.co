class AddStatusToUser < ActiveRecord::Migration[6.0]
  def change

    add_column :users, :status, :integer, default: 1

    OverviewUser.all(filter: "{On / Off} = 'Off'").each do |airtable_user|
      user = User.find_by(id: airtable_user['Builder_id'])
      user.update(status: 0) if user.present?
    end

  end
end
