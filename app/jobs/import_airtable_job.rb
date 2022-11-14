class ImportAirtableJob < ApplicationJob
  include SuckerPunch::Job

  def perform

    ###########
    ## USERS ##
    ###########

    # OverviewUser.all.each do |airtable_user|

    #   unless airtable_user['Builder_id'].present?
    #     new_user = User.new(firstname: airtable_user['Firstname'], lastname: airtable_user['Lastname'], email: airtable_user['Email'], access_level: 'sevener', password: 'tititoto')
    #     new_user.save
    #   end

    #   user = User.find_by(id: airtable_user['Builder_id'])

    #   if user&.active? && airtable_user['On / Off'] == 'Off'
    #     user.update status: :inactive
    #   elsif user&.inactive? && airtable_user['On / Off'] == 'On'
    #     user.update status: :active
    #   end

    # end


    ######################
    ## CREATE TRAININGS ##
    ######################

    OverviewTraining.all(filter: "{Builder_id} = ''").each do |card|

      ActiveRecord::Base.connection_pool.with_connection do

        begin
          Training.import_airtable(card)
        rescue => e
          puts card
          puts e.message
        end

      end

    end

  end
end
