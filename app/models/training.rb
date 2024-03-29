class Training < ApplicationRecord
  belongs_to :client_contact
  has_one :client_company, through: :client_contact
  has_many :sessions, dependent: :destroy
  has_many :training_ownerships, dependent: :destroy
  has_many :users, through: :training_ownerships
  has_many :session_trainers, through: :sessions
  has_many :attendee_interests, dependent: :destroy
  has_many :invoice_items
  has_many :invoices
  has_many :forms, dependent: :destroy
  has_many :attendee_interests, dependent: :destroy
  validates :title, presence: true
  validates :vat, inclusion: { in: [ true, false ] }
  validates_uniqueness_of :refid
  accepts_nested_attributes_for :training_ownerships

  extend OrderAsSpecified


  # SEARCHING TRANINGS BY TRANING.title AND CLIENT_COMPANY.name
  include PgSearch::Model
  pg_search_scope :search_by_title_and_company,
    against: [ :title ],
    associated_against: {
      client_company: :name,
      users: [:firstname, :lastname],
    },
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents

  def start_time
    self.sessions.where.not(date: nil).minimum(:date)
  end

  def end_time
    self.sessions.where.not(date: nil).maximum(:date)
  end

  def next_session
    if self.end_time.present? && self.end_time >= Date.today
      # return self.sessions&.where('date >= ?', Date.today)&.order(date: :asc).first&.date
      return Session.where(training_id: self.id).where('date >= ?', Date.today)&.order(date: :asc).first&.date
    elsif self.end_time.present?
      return self.end_time
    else
      return Date.today
    end
  end

  def to_date?
    if self.sessions.where(date: nil).present?
      return true
    else
      return false
    end
  end

  def client_company
    self.client_contact.client_company
  end

  def title_for_copy
    self.title + ' : ' + self.refid
  end

  def owners
    self.training_ownerships.where(user_type: 'Owner').map(&:user)
  end

  def sidekicks
    self.training_ownerships.where(user_type: 'Sidekick').map(&:user)
  end

  def owner_ids
    self.training_ownerships.where(user_type: 'Owner').map(&:user_id)
  end

  def writers
    self.training_ownerships.where(user_type: 'Writer').map(&:user)
  end

  def writer_ids
    self.training_ownerships.where(user_type: 'Writer').map(&:user_id)
  end

  def trainers
    User.where_exists(:session_trainers, session_id: self.sessions.ids, status: nil)
  end

  def trainer_last_session(trainer)
    self.sessions.joins(:session_trainers).where(session_trainers: {user_id: trainer.id}).where.not(date: nil).order(date: :asc).last&.date
  end

  def attendees
    SessionAttendee.where(session_id: [self.sessions.ids]).map{|x| x.attendee}.uniq
  end

  def hours
    self.sessions.map{|x| x.duration * x.session_trainers.count}.sum
  end

  ##############
  ## AIRTABLE ##
  ##############

  def self.import_airtable(card)
    training = Training.find_by(id: card['Builder_id'])
    message = []

    creator = card['Creator'].present? ?
      User.find_by(id: OverviewUser.find(card['Creator'].join)['Builder_id']) : nil
    operator = card['Operator'].present? ?
      User.find_by(id: OverviewUser.find(card['Operator'].join)['Builder_id']) : nil
    knowers = card['Knower/Briefer'].present? ?
      User.where(id: OverviewUser.find_many(card['Knower/Briefer']).map{|x| x['Builder_id']}) : []

    if training.present?

      if card['Status'] == '12. Fail'
        begin
          training.destroy
          card['Builder_id'] = nil
          card.save
          message << "Training #{training.title} deleted"
        rescue => e
          message << "Failed to delete Training #{training.title}"
          puts message.first
          puts e.message
        end

        return message.first
      end

      begin
        card['Needs'].present? ? needs = card['Needs'] : needs = ''
        card['Objectives'].present? ? objectives = card['Objectives'] : objectives = ''
        infos = "Besoins\n\n" + needs + "\n\n\nObjectifs\n\n" + objectives

        training.update(title: card['Title']) if training.title != card['Title']
        training.update(unit_price: card['Unit Price']) if training.unit_price != card['Unit Price']
        training.update(infos: infos)

        current_creator = training.owners.first
        if current_creator != creator
          TrainingOwnership.find_or_create_by(user: (current_creator.presence || creator), training: training, user_type: 'Owner')
                           .update user: creator
        end

        current_operator = training.sidekicks.first
        if current_operator != operator
          TrainingOwnership.find_or_create_by(user: (current_creator.presence || creator), training: training, user_type: 'Sidekick')
                           .update user: operator
        end

        current_knowers = training.writers
        if current_knowers.map(&:id).sort != knowers.map(&:id).sort
          TrainingOwnership.where.not(training: training, user_type: 'Writer', user: knowers).destroy_all
          knowers.each do |knower|
            TrainingOwnership.find_or_create_by(training: training, user_type: 'Writer', user: knower)
          end
        end

        puts "missing partner update"
      rescue => e
        message << "Failed to update Training #{training.title}"
        puts message.first
        puts e.message
      end

    elsif card['Status'] != '12. Fail'

      if card['Partner Contact ⭐️'].present?
        contact = OverviewContact.find(card['Partner Contact ⭐️']&.join)
        company = OverviewClient.find(contact['Company/School']&.join)
        message << "Training has no Partner" unless company.id.present?

        unless contact['Builder_id'].present?

          begin
            unless company['Builder_id'].present?
              reference = (ClientCompany.where.not(reference: nil).order(id: :asc).last.reference[-8..-1].to_i + 1).to_s.rjust(8, '0') if ClientCompany.all.count != 0
              new_company = ClientCompany.create(name: company['Name'], address: company['Address'], zipcode: company['Zipcode'], city: company['City'], client_company_type: company['Type'], description: '', reference: reference)
              message << "Failed to create Partner." unless new_company.valid?
              company['Builder_id'] = new_company.id
              company.save
            end
          rescue => e
            message << "Failed to create Partner."
            puts message.first
            puts e.message
          end

          begin
            new_contact = ClientContact.new(name: contact['Firstname'] + ' ' + contact['Lastname'], email: contact['Email'], client_company_id: company['Builder_id'].to_i, title: '', role_description: '')
            message << "Failed to create Partner Contact." unless new_contact.save
            contact['Builder_id'] = new_contact.id
            contact.save
          rescue => e
            message << "Failed to create Partner Contact."
            puts message.first
            puts e.message
          end
        end

        begin
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
          else
            message << "Failed to create Training."
          end
        rescue => e
          message << "Failed to create Training."
          puts message.first
          puts e.message
          puts e.backtrace
        end

      else
        message << "Training has no Partner Contact"
      end

    end

    return message.present? ? message.first : training
  end

  def export_airtable
    # begin
      existing_card = Rails.env.production? ? OverviewTraining.find(self.airtable_id) : OverviewTraining.all(filter: "{Builder_id} = '#{self.id}'").first
      details = "Détail des sessions (date, horaires, intervenants):\n\n"
      seven_invoices = "Factures SEVEN :\n"

      OverviewNumbersRevenue.all(filter: "{Training_id} = '#{self.id}'").sort_by{|x| x['Invoice_id']}.each do |invoice|

        builder_invoice = InvoiceItem.find(invoice['Invoice_id'])

        if ['Training', 'Home', 'Deposit (Home)', 'Direction MS'].include?(invoice['Type'])
          if invoice['Paid'] == true
            seven_invoices += "[x] #{builder_invoice.uuid} \n"
          else
            seven_invoices += "[ ] #{builder_invoice.uuid} \n"
          end
        end

      end

      existing_card['Status'] = "11. Terminée" if (self.end_time.present? && self.end_time < Date.today && self.invoice_items.present? && self.invoice_items.where(status: ['Pending', 'Sent']).count == 0 && self.invoice_items.where(status: 'Paid').count > 0)

      self.sessions.each do |session|
        if session.date.present?
          details += "- #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')}"

          if session.session_trainers.present?
            trainers = ""

            session.session_trainers.each do |trainer|
              user = OverviewUser.all(filter: "{Builder_id} = '#{trainer.user_id}'")&.first

              if user['Tag'].present?
                trainers += "#{user['Tag']}, "
              else
                trainers += trainer.user.fullname + ', '
              end
            end

            trainers = trainers.chomp(', ')
            details += " - " + trainers + ' (' + session.duration.to_s + 'h)' + "\n"
          else
            details += " - A STAFFER"  + ' (' + session.duration.to_s + 'h)' + "\n"
          end
        end
      end

      self.update(title: existing_card['Title'])
      owners = existing_card['Owner']&.map{|owner| User.find(OverviewUser.find(owner)['Builder_id'])}

      if owners.present?
        owners.each do |owner|
          unless TrainingOwnership.where(training_id: self.id, user_id: owner.id, user_type: 'Owner').present?
            TrainingOwnership.create(training_id: self.id, user_id: owner.id, user_type: 'Owner')
            TrainingOwnership.where(training_id: self.id, user_type: 'Owner').where.not(user_id: owners&.map{|x| x.id}).destroy_all
          end
        end
      end

      writers = existing_card['Writers']&.map{|writer| User.find(OverviewUser.find(writer)['Builder_id'])}

      if writers.present?
        writers.each do |writer|
          unless TrainingOwnership.where(training_id: self.id, user_id: writer.id, user_type: 'Writer').present?
            TrainingOwnership.create(training_id: self.id, user_id: writer.id, user_type: 'Writer')
            TrainingOwnership.where(training_id: self.id, user_type: 'Writer').where.not(user_id: writers&.map{|x| x.id}).destroy_all
          end
        end
      end

      existing_card['Trainers'] = self.trainers.map{|x| OverviewUser.all(filter: "{Builder_id} = '#{x.id}'").first.id}
      existing_card['Start date'] = self.start_time.strftime('%Y-%m-%d') if self.start_time.present?
      existing_card['Due Date'] = self.end_time.strftime('%Y-%m-%d') if self.end_time.present?
      existing_card['Builder Sessions Datetime'] = details
      existing_card['Builder Update'] = Time.now.utc.iso8601(3)

      seveners_to_pay = ""
      seveners = true if self.trainers.map{|x|x.access_level}.to_set.intersect?(['sevener+', 'sevener'].to_set)

      if seveners
        self.trainers.where(access_level: ['sevener+', 'sevener']).each do |user|
          numbers_card = OverviewNumbersSevener.all(filter: "{Training_id} = '#{self.id}'").select{|x| x['User_id'] == user.id}&.first

          if numbers_card['Total Due (incl. VAT and Expenses)'] == numbers_card['Total Paid']
            if numbers_card['Billing Type'] == 'Hourly'
              seveners_to_pay += "[x] #{user.fullname} : #{numbers_card['Unit Number']}h x #{numbers_card['Unit Price']}€ = #{numbers_card['Unit Number']*numbers_card['Unit Price']}€\n"
            elsif numbers_card['Billing Type'] == 'Flat rate'
              seveners_to_pay += "[x] #{user.fullname} : #{numbers_card['Unit Price']}€\n"
            end
          else
            if numbers_card['Billing Type'] == 'Hourly'
              seveners_to_pay += "[ ] #{user.fullname} : #{numbers_card['Unit Number']}h x #{numbers_card['Unit Price']}€ = #{numbers_card['Unit Number']*numbers_card['Unit Price']}€ (Montant restant du : #{numbers_card['Total Due (incl. VAT and Expenses)'] - numbers_card['Total Paid']}€)\n"
            elsif numbers_card['Billing Type'] == 'Flat rate'
              seveners_to_pay += "[ ] #{user.fullname} : #{numbers_card['Unit Price']}€\n"
            end
          end
        end
      else
        seveners_to_pay += "[x] Aucun\n"
      end

      existing_card['Seveners to pay'] = seveners_to_pay unless seveners_to_pay == ''
      existing_card['SEVEN Invoice(s)'] = seven_invoices
      existing_card.save
    # rescue
    # end
  end

  def export_numbers_activity
    # begin
      activities = OverviewNumbersActivity.all(filter: "{Builder_id} = #{self.id}")
      activities.each{|record| record.destroy}
      card = OverviewTraining.all(filter: "{Builder_id} = '#{self.id}'")&.first

      self.sessions.each do |session|

        if session.date.present?
          session.session_trainers.where(status: nil).each do |trainer|
            new_activity = OverviewNumbersActivity.create('Training' => [card.id], 'Date' => session.date.strftime('%Y-%m-%d'), 'Trainer' => [OverviewUser.all(filter: "{Builder_id} = '#{trainer.user_id}'")&.first&.id])
            new_activity['Hours'] = session.duration

            if card['Unit Type'] == 'Hour'
              new_activity['Revenue'] = new_activity['Hours'] * card['Unit Price']
            elsif ['Participant', 'Half day', 'Day', 'Flat rate'].include?(card['Unit Type'])
              new_activity['Revenue'] = card['Unit Number'] * card['Unit Price'] / (self.sessions.map{|x| x.duration}.sum * session.users.count) * session.duration
            end

            new_activity['Revenue'] = 0 unless new_activity['Revenue'].present?
            new_activity.save
          end
        end

      end
    # rescue
    # end
  end

  def export_numbers_sevener(user)
    cards = OverviewNumbersSevener.all(filter: "{Training_id} = '#{self.id}'")

    cards.each do |trainer|
      unless self.trainers.map{|x| x.id}.include?(OverviewUser.find(trainer['Sevener'].join)['Builder_id'])
        trainer.destroy
      end
    end

    if ['sevener', 'sevener+'].include?(user.access_level)
      sevener = OverviewUser.all(filter: "{Builder_id} = '#{user.id}'")&.first
      card = OverviewNumbersSevener.all(filter: "{Training_id} = '#{self.id}'").select{|x| x['Sevener'] == [sevener.id]}&.first
      invoices = OverviewInvoiceSevener.all(filter: "{Training_id} = '#{self.id}'").select{|x| x['Sevener'] == [sevener.id]}
      dates = ''

      unless card.present?
        # card = OverviewNumbersSevener.create('Training' => [OverviewTraining.all.select{|x| x['Builder_id'] == self.id}&.first.id], 'Sevener' => [sevener.id], 'Billing Type' => 'Hourly')
        card = OverviewNumbersSevener.create('Training' => [OverviewTraining.all(filter: "{Builder_id} = '#{self.id}'")&.first.id], 'Sevener' => [sevener.id], 'Billing Type' => 'Hourly')
        self.client_contact.client_company.client_company_type == 'Company' ? card['Unit Price'] = 80 : card['Unit Price'] = 40
      end

      unless card['Billing Type'] == 'Flat rate'
        card['Unit Number'] = user.hours(self)
      end

      card['Invoices Sevener'] = invoices.map{|x| x.id}
      card['Total Paid'] = invoices.select{|x| x['Amount'] if x['Status'] == 'Paid'}.map{|x| x['Amount']}.sum

      self.sessions.each do |session|
        dates += session.date.strftime('%d/%m/%Y') + "\n" if session.users.include?(user) if session.date.present?
      end

      card['Dates'] = dates
      card['User_id'] = user.id
      card['Training_id'] = self.id
      card.save
    end
  end

  def self.export_numbers_activity_cumulation
    UpdateCumulationChartJob.perform_now
  end
end
