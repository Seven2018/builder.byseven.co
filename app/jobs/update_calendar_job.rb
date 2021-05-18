class UpdateCalendarJob < ApplicationJob
  include SuckerPunch::Job

  def perform(code, state, scope, client_options, training)
   # Gets clearance from OAuth
    client = Signet::OAuth2::Client.new(client_options)
    client.code = code
    client.update!(client.fetch_access_token!)
    # Initiliaze GoogleCalendar
    service = Google::Apis::CalendarV3::CalendarService.new
    service.authorization = client
    # Get the targeted session
    session_ids = Base64.decode64(state).split('|')[1].split(',').map{|x| x.to_i}
    command = Base64.decode64(state).split('|').first.split(',').first
    # Calendars ids
    calendars_ids = {'other' => 'vum1670hi88jgei65u5uedb988@group.calendar.google.com'}
    User.where(access_level: ['super admin','admin']).each{|x| calendars_ids[x.id] = x.email}
    # Lists the users and the ids of the events to be deleted
    SessionTrainer.where(session_id: session_ids).each do |session_trainer|
      begin
        if ['super admin', 'admin'].include?(session_trainer.user.access_level)
          service.delete_event(session_trainer.user.email, session_trainer.calendar_uuid)
        else
          service.delete_event(calendars_ids['other'], session_trainer.calendar_uuid)
        end
        session_trainer.update(calendar_uuid: nil)
      rescue
      end
    end
    if command == 'purge_session' || command == 'purge_training'
      to_delete_string = Base64.decode64(state).split('|').last.split('%').last

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
      return
    else
      # Lists the users for whom an event will be created
      list = command.split(',')
      # Creates the event in all the targeted calendars
      list.each do |ind|
        Session.where(id: session_ids).each do |session|
          unless SessionTrainer.where(session_id: session.id, user_id: ind.to_i).first&.calendar_uuid&.present?
            date = session&.date
            day, month, year = date.day, date.month, date.year
            start_time = session.start_time.change(day: day, month: month, year: year)
            end_time = session.end_time.change(day: day, month: month, year: year)
            events = []
            break_position = session.workshops.find_by(title: 'Pause Déjeuner')&.position
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
            else
              morning = [session.start_time]
              morning_duration = session.workshops.where('position < ?', break_position).map(&:duration).sum
              morning << session.start_time + morning_duration.minutes
              afternoon = [session.end_time - session.workshops.where('position > ?', break_position).map(&:duration).sum.minutes, session.end_time]
              [morning.change(day: day, month: month, year: year), afternoon.change(day: day, month: month, year: year)].each do |event|
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
          end
        end
      end
      return
    end
  end

  private

  def create_calendar_id(user_id, session_id, event, service, hash)
    event.id = SecureRandom.hex(32)
    session_trainer = SessionTrainer.where(user_id: user_id, session_id: session_id).first
    session_trainer.calendar_uuid.nil? ? session_trainer.update(calendar_uuid: event.id) : session_trainer.update(calendar_uuid: session_trainer.calendar_uuid + ' - ' + event.id)
    service.insert_event(hash[user_id.to_i], event)
  end
end
