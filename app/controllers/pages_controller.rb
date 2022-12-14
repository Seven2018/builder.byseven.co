class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :contact_form, :contact_form_becos]

  def home
    redirect_to trainings_path
  end

  def billing
    @to_pay = []

    OverviewNumbersSevener.all(filter: "User_id = '#{current_user.id}'").sort_by{|x| x['Due Date (Training)']}.each do |intervention|

      training = Training.find_by(id: intervention['Training_id'])

      next if training.nil?
      next if training.end_time.nil?

      if intervention['Total Due (excl. VAT)'].to_f - intervention['Total Paid'].to_f > 0
        @to_pay << {training: training, intervention: intervention}
      end

    end
  end

  def billing_completed
    @paid = []

    OverviewNumbersSevener.all(filter: "User_id = '#{current_user.id}'").sort_by{|x| x['Due Date (Training)']}.each do |intervention|

      training = Training.find_by(id: intervention['Training_id'])

      next if training.nil?
      next if training.end_time.nil?

      if intervention['Total Due (excl. VAT)'].to_f - intervention['Total Paid'].to_f <= 0
        @paid << {training: training, intervention: intervention}
      end

    end

    render partial: "pages/billing/trainings_list", locals: {type: "Archived", list: @paid}
  end

  def account_invoice
    InvoiceItem.account_invoice
    redirect_to report_path
  end


  ####################################
  ## LEARN BY SEVEN WEBSITE (TOOLS) ##
  ####################################

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


  ##############
  ## AIRTABLE ##
  ##############

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

  def export_numbers_activity_cumulation
    UpdateCumulationChartJob.perform_async(Date.today)
    redirect_to trainings_path
  end

  ##############
end


