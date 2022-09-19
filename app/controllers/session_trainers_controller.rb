class SessionTrainersController < ApplicationController
  GOOGLE_CALENDAR_LINK='https://calendar.google.com/calendar'

  def update_calendar
    @session_trainer = SessionTrainer.new
    authorize @session_trainer
    training = Training.find(params[:training_id])
    sessions_ids = ''
    training.sessions.each do |session|
      sessions_ids += session.id.to_s + ','
    end

    trainers_list = []
    training.trainers.each do |user|
      trainers_list << user.id.to_s
    end

    UpdateAirtableJob.perform_async(training, true)
    redirect_to redirect_path(training_id: "/#{training.id}/", session_id: "|#{training.sessions.ids.join(',')}|", list: trainers_list.join(','))
  end

  def redirect
    skip_authorization

    begin
      client = Signet::OAuth2::Client.new(client_options)

      if params[:user_ids].present?
        client.update!(state: Base64.encode64(params[:list]+','+params[:session_id]+','+params[:training_id]+','+params[:user_ids]))
      else
        client.update!(state: Base64.encode64(params[:list]+','+params[:session_id]+','+params[:training_id]))
      end

      link = client.authorization_uri.to_s
    rescue
      link = GOOGLE_CALENDAR_LINK
    end
    redirect_to link
  end

  def calendars
    skip_authorization
    # Gets clearance from OAuth
    client = Signet::OAuth2::Client.new(client_options)
    client.code = params[:code]
    client.update!(client.fetch_access_token!)

    # Initiliaze GoogleCalendar
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client

    # Get the targeted session
    training_id = Base64.decode64(params[:state]).split('/')[1]
    training = Training.find(training_id)
    session_ids = Base64.decode64(params[:state]).split('|')[1].split(',').map{|x| x.to_i}
    command = Base64.decode64(params[:state]).split('|').first

    # Will execute if a session was deleted
    if command[0...-1] == 'purge_session'
      SessionTrainer.where(session_id: session_ids).each do |session_trainer|
        delete_calendar_event(session_trainer, service)
      end
      Session.find(session_ids.join).destroy
      redirect_to training_path(training)
      return
    else
      # TO UPDATE IF NEEDED
      # UpdateCalendarJob.perform_async(session_ids, command, service, client_options)

      # Calendars ids
      calendars_ids = {'other' => 'vum1670hi88jgei65u5uedb988@group.calendar.google.com'}
      User.where(access_level: ['super admin','admin']).each{|x| calendars_ids[x.id] = x.email}

      # Lists the users and the ids of the events to be deleted
      SessionTrainer.where(session_id: session_ids).each do |session_trainer|

        # Remove events for trainers previously staffed and now cancelled
        if session_trainer.status == 'to_delete'
          delete_calendar_event(session_trainer, service)
          session_trainer.destroy
        end

      end

      # Lists the users for whom an event will be created
      list = command.split(',')

      # Creates the event in all the targeted calendars
      list.each do |ind|

        Session.where(id: session_ids).each do |session|

          if session.date.nil?
            next
          end

          date = session&.date
          day, month, year = date.day, date.month, date.year
          start_time = session.start_time.change(day: day, month: month, year: year)
          end_time = session.end_time.change(day: day, month: month, year: year)
          trainers = []

          session.users.each do |trainer|
            trainers << {email: trainer.email}
          end

          events = []
          break_workshop = session.workshops.find_by(title: 'Pause Déjeuner')
          break_position = break_workshop&.position

          # If session does not contain a lunch break
          if break_position.nil?
            events << Google::Apis::CalendarV3::Event.new({
              start: {
                date_time: start_time.rfc3339.slice(0...-1),
                time_zone: 'Europe/Paris',
              },
              end: {
                date_time: end_time.rfc3339.slice(0...-1),
                time_zone: 'Europe/Paris',
              },
              summary: session.training.client_company.name + " - " + session.training.title
            })

          # If session does contain a lunch break, two separate events will be created
          else
            morning = [session.start_time.change(day: day, month: month, year: year)]
            morning_duration = session.workshops.where('position < ?', break_position).map(&:duration).sum
            morning << (session.start_time + morning_duration.minutes).change(day: day, month: month, year: year)
            afternoon = [(session.start_time + morning_duration.minutes + break_workshop.duration.minutes).change(day: day, month: month, year: year), session.end_time.change(day: day, month: month, year: year)]

            [morning, afternoon].each do |event|

              events << Google::Apis::CalendarV3::Event.new({
                start: {
                  date_time: event[0].rfc3339.slice(0...-1),
                  time_zone: 'Europe/Paris',
                },
                end: {
                  date_time: event[1].rfc3339.slice(0...-1),
                  time_zone: 'Europe/Paris',
                },
                summary: session.training.client_company.name + " - " + session.training.title
              })

            end
          end

          events.each_with_index do |event, event_idx|
            count = events.count

            # Events to create in Seven Team Calendars
            if User.where(access_level: ['super admin', 'admin']).map{|x| x.id.to_s}.include?(ind)
              create_calendar_event(service, calendars_ids, ind, session.id, event, event_idx, count)

            # Events to create in the Sevener Calendar
            else
              sevener = User.find(ind)
              event.summary = session.training.client_company.name + " - " + session.training.title + " - " + sevener.fullname

              create_calendar_event(service, calendars_ids, ind, session.id, event, event_idx, count, 'sevener')
            end

          end

        end

      end
    end
    redirect_to training_path(training)
  end

  # Allows management of SessionTrainers for target Session
  def link_to_session
    session_trainer = SessionTrainer.new
    authorize session_trainer
    @page = params[:link][:page]
    @session = Session.find(params[:link][:session_id])
    user_ids = params[:link][:trainer_ids].split(',')

    # Select all selected Users and create a SessionTrainer
    user_ids.each do |user_id|
      if SessionTrainer.where(user_id: user_id, session_id: @session.id).empty?
        SessionTrainer.create(user_id: user_id, session_id: @session.id)
      elsif existing = SessionTrainer.find_by(user_id: user_id, session_id: @session.id, status: 'to_delete')
        existing.update(status: nil)
      end
    end

    # Select all not selected Users and get rid of their SessionTrainer (destroy if calendar_uuid is nil, mark for deletion otherwise)
    SessionTrainer.where(session_id: @session.id).where.not(user_id: user_ids).each do |session_trainer|
      if session_trainer.calendar_uuid.nil?
        session_trainer.destroy
      else
        session_trainer.update(status: 'to_delete')
      end
    end

    UpdateAirtableJob.perform_async(@session.training, true)

    respond_to do |format|
      format.js
    end
  end

  # Allows management of SessionTrainers for target Session
  def link_to_training
    session_trainer = SessionTrainer.new
    authorize session_trainer
    @training = Training.find(params[:link][:training_id])
    user_ids = params[:link][:trainer_ids].split(',')

    # Select all Users whose checkbox is checked and create a SessionTrainer
    user_ids.each do |user_id|
      @training.sessions.each do |session|
        unless SessionTrainer.find_by(user_id: user_id, session_id: session.id).present?
          SessionTrainer.create(user_id: user_id, session_id: session.id)
        end
      end
    end

    # Select all not selected Users and get rid of their SessionTrainer (destroy if calendar_uuid is nil, mark for deletion otherwise)
    SessionTrainer.where(session_id: @training.sessions.ids).where.not(user_id: user_ids).each do |session_trainer|
      if session_trainer.calendar_uuid.nil?
        session_trainer.destroy
      else
        session_trainer.update(status: 'to_delete')
      end
    end

    UpdateAirtableJob.perform_async(@training, true)
    respond_to do |format|
      format.js
    end
  end

  # Remove all trainers before session deletion
  def remove_session_trainers
    skip_authorization
    @session = Session.find(params[:session_id])
    training = @session.training

    UpdateAirtableJob.perform_async(@session.training, true)

    redirect_to redirect_path(training_id: "/#{training.id}/", session_id: "|#{@session.id}|", list: "purge_session")
  end

  # Remove all trainers from all session before training deletion
  def remove_training_trainers
    skip_authorization
    training = Training.find(params[:training_id])

    sessions_ids = ''
    training.sessions.each do |session|
      sessions_ids += session.id.to_s + ','
    end

    UpdateAirtableJob.perform_async(training, true)

    redirect_to redirect_path(training_id: "/#{training.id}/", session_id: "|#{sessions_ids[0...-1]}|", list: 'purge_training')
  end

  private

  ############################
  ## GOOGLE::APIS::CALENDAR ##
  ############################

  def client_options
    {
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      redirect_uri: "#{request.base_url}/calendars"
    }
  end

  def create_calendar_event(service, hash, user_id, session_id, event, event_idx, events_count, user_type = 'seven')
    session_trainer = SessionTrainer.find_by(user_id: user_id, session_id: session_id)
    return if session_trainer.nil?

    google_calendar = user_type == 'seven' ? hash[user_id.to_i] : hash['other']
    calendar_uuid = session_trainer.calendar_uuid

    # If the session contains a lunch break, two events are created and their ids stored as follows in calendar_uuid => 'id1 - id2'
    event.id = calendar_uuid&.split(' - ')
    event.id = event.id[event_idx] if event.id.present?

    unless event.id.present?
      event.id = SecureRandom.hex(32)
    end


    # If the session previously had a lunch break but does not any longer, remove the second event
    if events_count == 1 && calendar_uuid&.split(' - ')&.count == 2
      service.delete_event(google_calendar, calendar_uuid.split(' - ')[1])
    end

    if calendar_uuid.nil? || (events_count == 1 && event.id != calendar_uuid)
      session_trainer.update(calendar_uuid: event.id)
    elsif calendar_uuid.split(' - ').count < 2 && events_count == 2 && event.id != calendar_uuid
      session_trainer.update(calendar_uuid: calendar_uuid + ' - ' + event.id)
    end

    begin
      service.update_event(google_calendar, event.id, event)
    rescue
      service.insert_event(google_calendar, event)
    end
  end

  def delete_calendar_event(session_trainer, service)
    begin
      return if session_trainer.calendar_uuid.nil?

      calendar_uuids = session_trainer.calendar_uuid.split(' - ')

      if ['super admin', 'admin'].include?(session_trainer.user.access_level)
        calendar_uuids.each do |calendar_uuid|
          service.delete_event(session_trainer.user.email, calendar_uuid)
        end
      else
        calendar_uuids.each do |calendar_uuid|
          service.delete_event('vum1670hi88jgei65u5uedb988@group.calendar.google.com', calendar_uuid)
        end
      end

    rescue
    end
  end

  ############################

  def session_trainer_params
    params.require(:session_trainer).permit(:type, :unit_price)
  end
end
