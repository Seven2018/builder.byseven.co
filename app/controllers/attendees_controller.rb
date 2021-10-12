class AttendeesController < ApplicationController
  before_action :set_attendee, only: [:show]
  before_action :authenticate_user!, except: [:new, :create, :template_csv, :import]
  invisible_captcha only: [:create], honeypot: :subtitle

  def index
    skip_authorization
    if params[:client_company_id].present?
      @client_company = ClientCompany.find(params[:client_company_id])
      @attendees = policy_scope(Attendee).where(client_company_id: @client_company.id).order(lastname: :asc)
    elsif params[:training_id].present?
      @attendees = policy_scope(Attendee).joins(:session_attendees).where(session_attendees: {session_id: Training.find(params[:training_id]).sessions.ids}).uniq
    elsif params[:session_id].present?
      @attendees = Session.find(params[:session_id]).attendees
    else
      @attendees = policy_scope(Attendee).order(lastname: :asc)
    end
  end

  def show
    authorize @attendee
  end

  def new
    @attendee = Attendee.new
    authorize @attendee
  end

  def create
    @attendee = Attendee.new(attendee_params)
    authorize @attendee
    training = Training.find(params[:attendee][:training_id].to_i)
    form = Form.find(params[:attendee][:form_id].to_i)
    @attendee.update(client_company_id: training.client_contact.client_company.id)
    if @attendee.save
      redirect_to training_form_path(training, form, search: {email: @attendee.email}, auth_token: @attendee.client_company.auth_token)
      flash[:notice] = 'Compte créé avec succès'
    else
      flash[:notice] = 'Erreur'
    end
  end

  # Creates new Attendees from an imported list
  def import
    @attendees = Attendee.import(params[:file], Training.find(params[:id]).client_contact.client_company_id)
    skip_authorization
    flash[:notice] = 'Import terminé'
    redirect_back(fallback_location: root_path)
  end

  # Exports a list of Attendees attending the current Session
  def export
    @attendees = Attendee.joins(:session_attendees).where(session_attendees: {session_id: params[:id]})
    session = Session.find(params[:id])
    skip_authorization
    respond_to do |format|
      format.html
      format.csv { send_data @attendees.to_csv, :filename => "Participants - #{session.training.title} - #{session.title} - #{session.date.strftime('%d%m%Y')}.csv"}
    end
  end

  def template_csv
    skip_authorization
    client_company_id = ClientCompany.find(params[:client_company_id]).id
    @attendees = Attendee.where(client_company_id: client_company_id)
    respond_to do |format|
      format.csv { send_data @attendees.to_csv_template, :filename => "Template import participants SEVEN.csv"}
    end
  end

  def import_attendees_form
    skip_authorization
    @training = Training.find(params[:training_id]) if params[:training_id].present?
    @session = Session.find(params[:session_id]) if params[:session_id].present?
  end

  def import_attendees
    skip_authorization
    attendees_array = JSON.parse(params[:import][:attendees])
    params[:import][:training_id].present? ? training = Training.find(params[:import][:training_id]) : training = nil
    params[:import][:session_id].present? ? session = Session.find(params[:import][:session_id]) : session = nil
    attendees_array.each do |attendee|
      new_attendee = Attendee.new(firstname: attendee[0], lastname: attendee[1], email: attendee[2])
      if attendee[3].present?
        new_attendee.client_company_id = attendee[3].to_i
      else
        if training.present?
          new_attendee.client_company_id = training.client_company.id
        else
          new_attendee.client_company_id = session.training.client_company.id
        end
      end
      new_attendee.save
      if training.present?
        training.sessions.each do |tr_session|
          SessionAttendee.create(session_id: tr_session.id, attendee_id: new_attendee.id)
        end
      elsif session.present?
        SessionAttendee.create(session_id: params[:import][:session_id], attendee_id: new_attendee.id)
      end
    end
    if training.present?
      redirect_to training_path(training), notice: "Attendees successfully imported to #{training.client_company.name} - #{training.title}"
    else
      redirect_to training_path(session.training), notice: "Attendees successfully imported to #{session.title}"
    end
  end

  private

  def attendee_params
    params.require(:attendee).permit(:firstname, :lastname, :employee_id, :email)
  end

  def set_attendee
    @attendee = Attendee.find(params[:id])
  end
end
