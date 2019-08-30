class AttendeesController < ApplicationController
  before_action :set_training, only: [:form]
  before_action :authenticate_user!, except: [:form, :new, :create]
  invisible_captcha only: [:create], honeypot: :subtitle

  def form
    @attendee = Attendee.new
    authorize @attendee
    @sessions = @training.sessions
    if params[:search] && params[:search][:email]
      @attendee = Attendee.find_by(email: params[:search][:email])
    elsif params[:attendee]
      @attendee = Attendee.find(params[:attendee].to_i)
    end
  end

  def new
    @attendee = Attendee.new
    authorize @attendee
  end

  def create
    @attendee = Attendee.new(attendee_params)
    authorize @attendee
    @attendee.update(client_company_id: Training.find(params[:attendee][:training_id].to_i).client_contact.client_company.id)
    if @attendee.save
      redirect_to training_attendees_form_path(Training.find(params[:attendee][:training_id].to_i), attendee: @attendee)
      flash[:notice] = 'Compte créer avec succès'
    else
      flash[:notice] = 'Erreur'
    end
  end

  def import
    @attendees = Attendee.import(params[:file])
    skip_authorization
    flash[:notice] = 'Import terminé'
    redirect_back(fallback_location: root_path)
  end

  private

  def attendee_params
    params.require(:attendee).permit(:firstname, :lastname, :employee_id, :email)
  end

  def set_training
    @training = Training.find(params[:training_id])
  end
end