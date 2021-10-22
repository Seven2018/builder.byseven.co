Airrecord.api_key = Rails.application.credentials.airtable_key

class IncomingContactBecosRecruiter < Airrecord::Table
  self.base_key = 'appYT5PVZu72h7ECX'
  self.table_name = 'Recruiters'
end
