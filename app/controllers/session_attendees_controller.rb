class SessionAttendeesController < ApplicationController
  before_action :authenticate_user!, except: [:destroy, :create]

  def create
    @session_attendee = SessionAttendee.new(session_id: params[:session_id], attendee_id: params[:attendee_id])
    authorize @session_attendee
    if @session_attendee.save
      flash[:notice] = "Vous êtes désormais inscrit à la session #{@session_attendee.session.title}."
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    @session_attendee = SessionAttendee.find_by(session_id: params[:session_id], attendee_id: params[:attendee_id])
    authorize @session_attendee
    @session_attendee.destroy
    flash[:notice] = "Vous êtes désinscrit de la session #{@session_attendee.session.title}."
    redirect_back(fallback_location: root_path)
  end
end
