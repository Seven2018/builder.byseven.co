class SessionTrainersController < ApplicationController
  def redirect
    skip_authorization
    client = Signet::OAuth2::Client.new(client_options)
    # Allows to pass informations through the Google Auth as a complex string
    client.update!(state: Base64.encode64(params[:list]+','+params[:session_id]+','+params[:to_delete]))
    redirect_to client.authorization_uri.to_s
  end

  def callback
    client = Signet::OAuth2::Client.new(client_options)
    client.code = params[:code]
    response = client.fetch_access_token!
    session[:authorization] = response
    redirect_to "#{create_url}/?code=#{params[:code]}"
  end

  def calendars
    # Gets clearance from OAuth
    client = Signet::OAuth2::Client.new(client_options)
    skip_authorization
    client.code = params[:code]
    client.update!(client.fetch_access_token!)
    # Initiliaze GoogleCalendar
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client
    # Get the targeted session
    session_ids = Base64.decode64(params[:state]).split('|')[1].split(',')
    training = Session.find(session_ids[0]).training
    # Calendars ids
    calendars_ids = {'other' => 'vum1670hi88jgei65u5uedb988@group.calendar.google.com'}
    User.where(access_level: ['super admin','admin']).each{|x| calendars_ids[x.id] = x.email}
    # Lists the users and the ids of the events to be deleted
    to_delete_string = Base64.decode64(params[:state]).split('|').last.split('%').last

    # Deletes the events
    to_delete_string.split(',').each do |pair|
      key = pair.split(':')[0]
      value = pair.split(':')[1]
      begin
        if User.where(access_level: ['super admin', 'admin']).map{|x| x.id.to_s}.include?(key)
          service.delete_event(calendars_ids[key.to_i], value) if value.present?
        else
          service.delete_event(calendars_ids['other'], value) if value.present?
        end
      rescue
      end
    end

    command = Base64.decode64(params[:state]).split('|').first
    if command[0...-1] == 'purge_session'
      Session.where(id: session_ids).destroy_all
      redirect_to training_path(training)
      return
    elsif command[0...-1] == 'purge_training'
      training.destroy
      redirect_to trainings_path(page: 1)
      return
    else
      # Lists the users for whom an event will be created
      list = command.split(',')
      # Creates the event in all the targeted calendars
      list.each do |ind|
        Session.where(id: session_ids).each do |session|
          unless SessionTrainer.where(session_id: session.id, user_id: ind.to_i).first&.calendar_uuid&.present?
            day = session&.date
            events = []
            begin
              break_position = session.workshops.find_by(title: 'Pause Déjeuner')&.position
              if break_position.nil?
                # Creates the event to be added to one or several calendars
                events << Google::Apis::CalendarV3::Event.new({
                  start: {
                    date_time: day.to_s+'T'+session.start_time.strftime('%H:%M:%S'),
                    time_zone: 'Europe/Paris',
                  },
                  end: {
                    date_time: day.to_s+'T'+session.end_time.strftime('%H:%M:%S'),
                    time_zone: 'Europe/Paris',
                  },
                  summary: session.training.client_company.name + " - " + session.training.title
                })
              else
                morning = [session.start_time]
                morning_duration = session.workshops.where('position < ?', break_position).map(&:duration).sum
                morning << session.start_time + morning_duration.minutes
                afternoon = [session.end_time - session.workshops.where('position > ?', break_position).map(&:duration).sum.minutes, session.end_time]
                [morning, afternoon].each do |event|
                  events << Google::Apis::CalendarV3::Event.new({
                  start: {
                    date_time: day.to_s+'T'+event.first.strftime('%H:%M:%S'),
                    time_zone: 'Europe/Paris',
                  },
                  end: {
                    date_time: day.to_s+'T'+event.last.strftime('%H:%M:%S'),
                    time_zone: 'Europe/Paris',
                  },
                  summary: session.training.client_company.name + " - " + session.training.title
                })
                end
              end
              events.each do |event|
                if User.where(access_level: ['super admin', 'admin']).map{|x| x.id.to_s}.include?(ind)
                  create_calendar_id(ind, session.id, event, service, calendars_ids)
                else
                  sevener = User.find(ind)
                  initials = sevener.initials
                  event.summary = session.training.client_company.name + " - " + session.training.title + " - " + initials
                  event.id = SecureRandom.hex(32)
                  session_trainer = SessionTrainer.where(user_id: sevener.id, session_id: session.id).first
                  session_trainer.calendar_uuid.nil? ? session_trainer.update(calendar_uuid: event.id) : session_trainer.update(calendar_uuid: session_trainer.calendar_uuid + ' - ' + event.id)
                  service.insert_event(calendars_ids['other'], event)
                end
              end
            rescue
            end
          end
        end
      end
      redirect_to training_path(training)
      return
    end
    redirect_to training_path(training)
  end

  # Allows management of SessionTrainers through a checkbox collection
  def create
    @session_trainer = SessionTrainer.new
    authorize @session_trainer
    @session = Session.find(params[:session_id])
    # Select all Users whose checkbox is unchecked and destroy their SessionTrainer, if existing
    SessionTrainer.where(session_id: @session.id).map{|x| x.user.id}.each do |ind|
      unless SessionTrainer.where(session_id: @session.id, user_id: ind).empty?
        to_delete = SessionTrainer.where(session_id: @session.id, user_id: ind).first
        unless to_delete.calendar_uuid.nil?
          @session.training.gdrive_link.nil? ? @session.training.update(gdrive_link: ind.to_s + ':' + to_delete.calendar_uuid + ',') : @session.training.update(gdrive_link: @session.training.gdrive_link + ind.to_s + ':' + to_delete.calendar_uuid + ',')
        end
        to_delete.destroy
      end
    end
    # Select all Users whose checkbox is checked and create a SessionTrainer
    array = params[:session][:user_ids].reject(&:empty?).map(&:to_i)
    array.each do |ind|
      if SessionTrainer.where(session_id: @session.id, user_id: ind).empty?
        if @session.training.client_contact.client_company.client_company_type == 'Company'
          session_trainer = SessionTrainer.create(session_id: @session.id, user_id: ind, unit_price: 80)
        else
          session_trainer = SessionTrainer.create(session_id: @session.id, user_id: ind, unit_price: 40)
        end
      end
    end
    # UpdateAirtableJob.perform_async(@session.training, true)
    redirect_back(fallback_location: root_path)
  end

  def create_all
    @session_trainer = SessionTrainer.new
    authorize @session_trainer
    training = Training.find(params[:training_id])
    # Select all Users whose checkbox is checked and create a SessionTrainer
    array = params[:training][:user_ids].drop(1).map(&:to_i)
    array.each do |ind|
      training.sessions.each do |session|
        if SessionTrainer.where(session_id: session.id, user_id: ind).empty?
          if training.client_contact.client_company.client_company_type == 'Company'
            session_trainer = SessionTrainer.create(session_id: session.id, user_id: ind, unit_price: 80)
          else
            session_trainer = SessionTrainer.create(session_id: session.id, user_id: ind, unit_price: 40)
          end
        end
      end
    end
    # Select all Users whose checkbox is unchecked and destroy their SessionTrainer, if existing
    (User.ids - array).each do |ind|
      training.sessions.each do |session|
        unless SessionTrainer.where(session_id: session.id, user_id: ind).empty?
          to_delete = SessionTrainer.where(session_id: session.id, user_id: ind).first
          unless to_delete.calendar_uuid.nil?
            session.training.gdrive_link.nil? ? session.training.update(gdrive_link: ind.to_s + ':' + to_delete.calendar_uuid + ',') : session.training.update(gdrive_link: session.training.gdrive_link + ind.to_s + ':' + to_delete.calendar_uuid + ',')
          end
          to_delete.destroy
        end
      end
    end
    # UpdateAirtableJob.perform_async(training, true)
    redirect_to training_path(training)
  end

  def update_calendar
    @session_trainer = SessionTrainer.new
    authorize @session_trainer
    training = Training.find(params[:training_id])
    event_to_delete = ''
    sessions_ids = ''
    training.sessions.each do |session|
      sessions_ids += session.id.to_s + ','
      # SessionTrainer.where(session_id: session.id).each do |session_trainer|
      #   if session_trainer.calendar_uuid.present?
      #     session.training.gdrive_link.nil? ? session.training.update(gdrive_link: session_trainer.user_id.to_s + ':' + session_trainer.calendar_uuid + ',') : session.training.update(gdrive_link: session.training.gdrive_link + session_trainer.user_id.to_s + ':' + session_trainer.calendar_uuid + ',')
      #   end
      # end
    end
    event_to_delete = training.gdrive_link[0...-1] unless !training.gdrive_link.present?
    training.update(gdrive_link: '')
    # training.sessions.each{|x| x.session_trainers.each{|y| y.update(calendar_uuid: nil)}}


    trainers_list = []
    training.trainers.each do |user|
      trainers_list << user.id.to_s
    end
    # UpdateAirtableJob.perform_now(training, true)
    # training.trainers.each{|y| training.export_numbers_sevener(y)}
    # training.export_airtable
    # training.export_numbers_activity
    redirect_to redirect_path(list: trainers_list.join(','), session_id: "|#{training.sessions.ids.join(',')}|", to_delete: "%#{event_to_delete}%")
  end

  def remove_session_trainers
    skip_authorization
    @session = Session.find(params[:session_id])

    event_to_delete = ''
    SessionTrainer.where(session_id: @session.id).each do |trainer|
      event_to_delete+=trainer.user_id.to_s+':'+trainer.calendar_uuid+',' if trainer.calendar_uuid.present?
    end
    event_to_delete = event_to_delete[0...-1]

    UpdateAirtableJob.perform_async(@session.training, true)
    # @session.training.export_airtable
    # @session.training.export_trainer_airtable
    redirect_to redirect_path(session_id: "|#{@session.id}|", list: 'purge_session', to_delete: "%#{event_to_delete}%")
  end

  def remove_training_trainers
    skip_authorization
    training = Training.find(params[:training_id])

    event_to_delete = ''
    sessions_ids = ''
    training.sessions.each do |session|
      SessionTrainer.where(session_id: session.id).each do |trainer|
        event_to_delete+=trainer.user_id.to_s+':'+trainer.calendar_uuid+',' if trainer.calendar_uuid.present?
      end
      sessions_ids += session.id.to_s + ','
    end
    event_to_delete = event_to_delete[0...-1]

    UpdateAirtableJob.perform_async(training, true)
    # training.export_airtable
    # training.export_trainer_airtable
    redirect_to redirect_path(session_id: "|#{sessions_ids[0...-1]}|", list: 'purge_training', to_delete: "%#{event_to_delete}%")
  end

  def update
    @session_trainer = SessionTrainer.find(:id)
    authorize @session_trainer
    @session_trainer.update(session_trainer_params)
    redirect_to request.referrer if @session_trainer.present?
  end

  private

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

  def create_calendar_id(user_id, session_id, event, service, hash)
    event.id = SecureRandom.hex(32)
    session_trainer = SessionTrainer.where(user_id: user_id, session_id: session_id).first
    session_trainer.calendar_uuid.nil? ? session_trainer.update(calendar_uuid: event.id) : session_trainer.update(calendar_uuid: session_trainer.calendar_uuid + ' - ' + event.id)
    service.insert_event(hash[user_id.to_i], event)
  end

  def session_trainer_params
    params.require(:session_trainer).permit(:type, :unit_price)
  end
end
