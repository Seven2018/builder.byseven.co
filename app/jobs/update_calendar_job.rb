class UpdateCalendarJob < ApplicationJob
  include SuckerPunch::Job

  def perform(session_ids, command, service, client_options)
    # Calendars ids
    calendars_ids = {'other' => 'vum1670hi88jgei65u5uedb988@group.calendar.google.com'}
    User.where(access_level: ['super admin','admin']).each{|x| calendars_ids[x.id] = x.email}
    # Lists the users and the ids of the events to be deleted
    SessionTrainer.where(session_id: session_ids).each do |session_trainer|
      begin
        delete_calendar_id(session_trainer, service)
      rescue
      end
      session_trainer.update(calendar_uuid: nil)
    end
    # Lists the users for whom an event will be created
    list = command.split(',')
    # Creates the event in all the targeted calendars
    list.each do |ind|
      Session.where(id: session_ids).each do |session|
        if session.date.nil?
          break
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
          morning = [session.start_time.change(day: day, month: month, year: year)]
          morning_duration = session.workshops.where('position < ?', break_position).map(&:duration).sum
          morning << (session.start_time + morning_duration.minutes).change(day: day, month: month, year: year)
          afternoon = [(session.end_time - session.workshops.where('position > ?', break_position).map(&:duration).sum.minutes).change(day: day, month: month, year: year), session.end_time.change(day: day, month: month, year: year)]
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
        events.each do |event|
          #begin
            if User.where(access_level: ['super admin', 'admin']).map{|x| x.id.to_s}.include?(ind)
              create_calendar_id(ind, session.id, event, service, calendars_ids)
            else
              sevener = User.find(ind)
              event.summary = session.training.client_company.name + " - " + session.training.title + " - " + sevener.fullname
              event.id = SecureRandom.hex(32)
              session_trainer = SessionTrainer.where(user_id: sevener.id, session_id: session.id).first
              session_trainer.calendar_uuid.nil? ? session_trainer.update(calendar_uuid: event.id) : session_trainer.update(calendar_uuid: session_trainer.calendar_uuid + ' - ' + event.id)
              service.insert_event(calendars_ids['other'], event)
            end
          #rescue
          #end
        end
      end
    end
    return
    redirect_to training_path(training)
  end

  private

  def create_calendar_id(user_id, session_id, event, service, hash)
    event.id = SecureRandom.hex(32)
    session_trainer = SessionTrainer.where(user_id: user_id, session_id: session_id).first
    session_trainer.calendar_uuid.nil? ? session_trainer.update(calendar_uuid: event.id) : session_trainer.update(calendar_uuid: session_trainer.calendar_uuid + ' - ' + event.id)
    service.insert_event(hash[user_id.to_i], event)
  end

  def delete_calendar_id(session_trainer, service)
    begin
      calendar_uuids = session_trainer.calendar_uuid.split(' - ')
      if ['super admin', 'admin'].include?(session_trainer.user.access_level)
        calendar_uuids.each do |calendar_uuid|
          service.delete_event(session_trainer.user.email, calendar_uuid)
        end
      else
        calendar_uuids.each do |calendar_uuid|
          service.delete_event(calendars_ids['other'], calendar_uuid)
        end
      end
    rescue
    end
  end
end
