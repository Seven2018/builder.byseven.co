class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :contact_form, :contact_form_becos]

  def home
    redirect_to trainings_path
  end

  def billing
    @user = User.find(params[:user_id])
    @trainings = Training.joins(sessions: :session_trainers).where(sessions: {session_trainers: {user_id: @user.id}}).uniq
  end

  def contact_form
    unless params[:email_2]&.present? || params[:email]&.gsub(' ', '').empty?
      contact = IncomingContact.create('Name' => params[:name], 'Email' => params[:email], 'Tel' => params[:tel], 'Message' => params[:message], 'Training' => params[:training], 'Date' => DateTime.now.strftime('%Y-%m-%d'))
      IncomingContactMailer.new_incoming_contact(contact, User.where(id: [1, 3])).deliver
    else
      IncomingSpam.create('Name' => params[:name], 'Email' => params[:email], 'Message' => params[:message])
    end
    redirect_to 'https://learn.byseven.co/thank-you.html'
  end

  def contact_form_becos
    unless params[:email_2]&.present? || params[:email]&.gsub(' ', '').empty?
      if params[:type] == 'Participant'
        contact = IncomingContactBecos.create('Lastname' => params[:lastname].strip.titleize, 'Firstname' => params[:firstname].strip.titleize, 'Email' => params[:email].strip.downcase, 'Tel' => params[:phone], 'Linkedin' => params[:linkedin], 'Message' => params[:message], 'Chosen Date' => params[:date], 'Chosen Time' => params[:time], 'Newsletter' => params[:newsletter].present?)
      elsif params[:type] == 'Recruiter'
        contact = IncomingContactBecosRecruiter.create('Lastname' => params[:lastname].strip.titleize, 'Firstname' => params[:firstname].strip.titleize, 'Email' => params[:email].strip.downcase, 'Tel' => params[:phone], 'Linkedin' => params[:linkedin], 'Company' => params[:company].strip.titleize, 'Message' => params[:message], 'Newsletter' => params[:newsletter].present?)
      end
    end
    redirect_to 'https://learn.byseven.co/thank-you-becos.html'
  end

  def airtable_import_users
    OverviewUser.all.each do |user|
      if user['Builder_id'].nil?
        new_user = User.new(firstname: user['Firstname'], lastname: user['Lastname'], email: user['Email'], access_level: 'sevener', password: 'tititoto')
        new_user.save
      end
    end
    redirect_back(fallback_location: root_path)
    flash[:notice] = "Data imported from Airtable."
  end

  def import_airtable
    skip_authorization

    if params[:training_id].present?
      ImportAirtableJob.perform_async(params[:training_id])
    else
      ImportAirtableJob.perform_async

      redirect_to trainings_path
      flash[:notice] = 'Import en cours, veuillez patienter quelques instants.'
    end
  end

  def account_invoice
    InvoiceItem.account_invoice
    redirect_to report_path
  end

  def export_numbers_activity_cumulation
    UpdateCumulationChartJob.perform_async(Date.today)
    redirect_to trainings_path
  end
end


