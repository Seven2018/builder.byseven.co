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


    ###############
    ## TRAININGS ##
    ###############

    OverviewTraining.all(filter: "{Builder_id} = ''").each do |card|

      ActiveRecord::Base.connection_pool.with_connection do
        creator = card['Creator'].present? ?
          User.find_by(id: OverviewUser.find(card['Creator'].join)['Builder_id']) : nil
        operator = card['Operator'].present? ?
          User.find_by(id: OverviewUser.find(card['Operator'].join)['Builder_id']) : nil
        knowers = card['Knower/Briefer'].present? ?
          User.where(id: OverviewUser.find_many(card['Knower/Briefer']).map{|x| x['Builder_id']}) : []

          # if card['Status'] == '12. Fail'
          #   to_delete = Training.find_by(id: card['Builder_id'])
          #   if to_delete.present?
          #     begin
          #       to_delete.destroy
          #     rescue
          #     end
          #   end
          #   next
          # end

          # card['Needs'].present? ? needs = card['Needs'] : needs = ''
          # card['Objectives'].present? ? objectives = card['Objectives'] : objectives = ''
          # infos = "Besoins\n\n" + needs + "\n\n\nObjectifs\n\n" + objectives
          # training = Training.find_by(id: card['Builder_id'])

          # if training.nil?
          #   card['Builder_id'] = ''
          #   card.save
          #   next
          # end

          # training.update(title: card['Title']) if training.title != card['Title']
          # training.update(unit_price: card['Unit Price']) if training.unit_price != card['Unit Price']
          # training.update(infos: infos)

          # current_creator = training.owners.first

          # if current_creator != creator
          #   TrainingOwnership.find_or_create_by(user: (current_creator.presence || creator), training: training, user_type: 'Owner')
          #                    .update user: creator
          # end

          # current_operator = training.sidekicks.first
          # if current_operator != operator
          #   TrainingOwnership.find_or_create_by(user: (current_creator.presence || creator), training: training, user_type: 'Sidekick')
          #                    .update user: operator
          # end

          # current_knowers = training.writers
          # if current_knowers.map(&:id).sort != knowers.map(&:id).sort
          #   TrainingOwnership.where.not(training: training, user_type: 'Writer', user: knowers).destroy_all
          #   knowers.each do |knower|
          #     TrainingOwnership.find_or_create_by(training: training, user_type: 'Writer', user: knower)
          #   end
          # end

        if card['Partner Contact ⭐️'].present?
          contact = OverviewContact.find(card['Partner Contact ⭐️'].join)
          company = OverviewClient.find(contact['Company/School'].join)

          unless contact['Builder_id'].present?
            unless company['Builder_id'].present?
              reference = (ClientCompany.where.not(reference: nil).order(id: :asc).last.reference[-8..-1].to_i + 1).to_s.rjust(8, '0') if ClientCompany.all.count != 0
              new_company = ClientCompany.create(name: company['Name'], address: company['Address'], zipcode: company['Zipcode'], city: company['City'], client_company_type: company['Type'], description: '', reference: reference)
              company['Builder_id'] = new_company.id
              company.save
            end

            new_contact = ClientContact.new(name: contact['Firstname'] + ' ' + contact['Lastname'], email: contact['Email'], client_company_id: company['Builder_id'].to_i, title: '', role_description: '')
            new_contact.save
            contact['Builder_id'] = new_contact.id
            contact.save
          end

          company['Type'] == 'School' ? vat = false : vat = true
          vat = true if card['VAT'] == true
          card['Needs'].present? ? needs = card['Needs'] : needs = ''
          card['Objectives'].present? ? objectives = card['Objectives'] : objectives = ''
          infos = "Besoins\n\n" + needs + "\n\n\nObjectifs\n\n" + objectives
          training = Training.new(title: card['Title'],
                                  client_contact_id: contact['Builder_id'],
                                  refid: "#{Time.current.strftime('%y')}-#{(Training.last.refid[-4..-1].to_i + 1).to_s.rjust(4, '0')}",
                                  satisfaction_survey: 'https://learn.byseven.co/survey',
                                  unit_price: card['Unit Price'].to_f,
                                  training_type: card['Type'],
                                  vat: vat,
                                  infos: infos,
                                  airtable_id: card.id)

          if training.save
            card['Reference SEVEN'] = training.refid
            card['Builder_id'] = training.id
            card['Builder Update'] = Time.now.utc.iso8601(3)
            card.save

            TrainingOwnership.create(training: training, user: creator, user_type: 'Owner') if creator.present?
            TrainingOwnership.create(training: training, user: operator, user_type: 'Sidekick') if operator.present?

            knowers.each do |knower|
              TrainingOwnership.create(training: training, user: knower, user_type: 'Writer')
            end
          end

        end

      end

    end
  end
end
