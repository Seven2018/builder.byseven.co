class ImportAirtableJob < ApplicationJob
  include SuckerPunch::Job

  def perform
    OverviewTraining.all.each do |card|
      if card['Builder_id'].present?
        if card['Status'] == '12. Fail'
          to_delete = Training.find_by(id: card['Builder_id'])
          if to_delete.present?
            begin
              to_delete.destroy
            rescue
            end
          end
          next
        end
        card['Needs'].present? ? needs = card['Needs'] : needs = ''
        card['Objectives'].present? ? objectives = card['Objectives'] : objectives = ''
        infos = "Besoins\n\n" + needs + "\n\n\nObjectifs\n\n" + objectives
        training = Training.find(card['Builder_id'])
        training.update(title: card['Title']) if training.title != card['Title']
        training.update(unit_price: card['Unit Price']) if training.unit_price != card['Unit Price']
        training.update(infos: infos)
      elsif card['Partner Contact'].present?
        owners = OverviewUser.all.select{|x| if card['Owner'].present?; card['Owner'].include?(x.id); end}
        sidekicks = OverviewUser.all.select{|x| if card['Sidekick'].present?; card['Sidekick'].include?(x.id); end}
        writers = OverviewUser.all.select{|x| if card['Writers'].present?; card['Writers'].include?(x.id); end}
        contact = OverviewContact.find(card['Partner Contact'].join)
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
        training = Training.new(title: card['Title'], client_contact_id: contact['Builder_id'], refid: "#{Time.current.strftime('%y')}-#{(Training.last.refid[-4..-1].to_i + 1).to_s.rjust(4, '0')}", satisfaction_survey: 'https://learn.byseven.co/survey', unit_price: card['Unit Price'].to_f, training_type: card['Type'], vat: vat, infos: infos)
        if training.save
          card['Reference SEVEN'] = training.refid
          card['Builder_id'] = training.id
          card['Builder Update'] = Time.now.utc.iso8601(3)
          card.save
          owners.each do |owner|
            TrainingOwnership.create(training_id: training.id, user_id: owner['Builder_id'], user_type: 'Owner')
          end
          sidekicks.each do |owner|
            TrainingOwnership.create(training_id: training.id, user_id: owner['Builder_id'], user_type: 'Sidekick')
          end
          writers.each do |writer|
            TrainingOwnership.create(training_id: training.id, user_id: writer['Builder_id'], user_type: 'Writer')
          end
        end
      end
    end
  end
end
