class AttendeesController < ApplicationController
  before_action :set_training, only: [:form]
  before_action :authenticate_user!, except: [:form, :new, :create]
  invisible_captcha only: [:create], honeypot: :subtitle

  def new
    @attendee = Attendee.new
    authorize @attendee
  end

  def create
    @attendee = Attendee.new(attendee_params)
    authorize @attendee
    @attendee.update(client_company_id: Training.find(params[:attendee][:training_id].to_i).client_contact.client_company.id)
    if @attendee.save
      redirect_to training_form_path(Training.find(params[:attendee][:training_id].to_i), Form.find(params[:attendee][:form_id].to_i), search: {email: @attendee.email})
      flash[:notice] = 'Compte créé avec succès'
    else
      flash[:notice] = 'Erreur'
    end
  end

  def create_big_mamma
    @attendee = Attendee.new(attendee_params)
    authorize @attendee
    @attendee.update(client_company_id: ClientCompany.find_by(name: 'BIG MAMMA'))
    if @attendee.save
      redirect_to big_mamma_path(search: {email: @attendee.email})
      flash[:notice] = 'Compte créé avec succès'
    else
      flash[:notice] = 'Erreur'
    end
  end

  # Creates new Attendees from an imported list
  def import
    @attendees = Attendee.import(params[:file])
    skip_authorization
    flash[:notice] = 'Import terminé'
    redirect_back(fallback_location: root_path)
  end

  # Exports a list of Attendees attending the current Session
  def export
    @attendees = Attendee.joins(:session_attendees).where(session_attendees: {session_id: params[:id]})
    skip_authorization
    respond_to do |format|
      format.html
      format.csv { send_data @attendees.to_csv}
    end
  end

  private

  def attendee_params
    params.require(:attendee).permit(:firstname, :lastname, :employee_id, :email)
  end

  def set_training
    @training = Training.find(params[:training_id])
  end
end
