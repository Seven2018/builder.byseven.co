class SessionAttendeesController < ApplicationController
  before_action :authenticate_user!, except: [:destroy, :create, :create_kea_partners, :destroy_kea_partners, :test]

  def link_attendees
    skip_authorization
    session = Session.find(params[:id])
    attendee_ids = params[:session][:attendee_ids][1..-1]
    attendee_ids.each do |attendee_id|
      SessionAttendee.create(session_id: session.id, attendee_id: attendee_id)
    end
    redirect_to training_session_path(session.training, session)
    flash[:notice] = "Participants added to #{session.title}"
  end

  def link_attendees_to_training
    skip_authorization
    training = Training.find(params[:id])
    attendee_ids = params[:link][:attendee_ids][1..-1]
    attendee_ids.each do |attendee_id|
      training.sessions.each do |session|
        SessionAttendee.create(session_id: session.id, attendee_id: attendee_id)
      end
    end
    redirect_to training_path(training)
    flash[:notice] = "Participants added to #{training.title}"
  end

  def create
    @session = Session.find(params[:session_id])
    @attendee = Attendee.find(params[:attendee_id])
    @session_attendee = SessionAttendee.new(session_id: @session.id, attendee_id: params[:attendee_id])
    authorize @session_attendee
    if (@session.attendees.count <= (@session.attendee_number - 1)) && @session_attendee.save
      flash[:notice] = "Vous êtes désormais inscrit à la session #{@session_attendee.session.title}."
      redirect_back(fallback_location: root_path)
    end
  end

  def create_all
    skip_authorization
    attendees = []
    training = Training.find(params[:id])
    params[:attendees][:list].split("\r\n").each do |attendee|
      attendee = attendee.split(',')
      new_attendee = Attendee.new(firstname: attendee[0], lastname: attendee[1], email: attendee[2])
      new_attendee.client_company_id = training.client_contact.client_company_id
      if new_attendee.save
        attendees << new_attendee
      else
        attendees << Attendee.find_by(email: attendee[2])
      end
    end
    attendees.each do |attendee|
      training.sessions.each do |session|
        SessionAttendee.create(session_id: session.id, attendee_id: attendee.id)
      end
    end
    redirect_to training_path(training)
  end

  def destroy
    @session_attendee = SessionAttendee.find_by(session_id: params[:session_id], attendee_id: params[:attendee_id])
    authorize @session_attendee
    @session_attendee.destroy
    flash[:notice] = "Vous êtes désinscrit de la session #{@session_attendee.session.title}."
    redirect_back(fallback_location: root_path)
  end

  def import_for_training
    attendees = Attendee.import(params[:file], Training.find(params[:id]).client_contact.client_company_id)
    training = Training.find(params[:id])
    attendees.each do |attendee|
      training.sessions.each do |session|
        SessionAttendee.create(session_id: session.id, attendee_id: attendee.id)
      end
    end
    skip_authorization
    flash[:notice] = 'Import terminé'
    redirect_back(fallback_location: root_path)
  end
end

