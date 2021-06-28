Airrecord.api_key = Rails.application.credentials.airtable_key

class AirtableAttendee < Airrecord::Table
  self.base_key = 'appXwOgtOTscY3P7J'
  self.table_name = 'Attendees'
end
