Airrecord.api_key = Rails.application.credentials.airtable_key

class OverviewContact < Airrecord::Table
  Rails.env.production? ? self.base_key = 'appGm0wPMcSxAI6RH' : self.base_key = 'appmHNAokYy761xK0'
  self.table_name = 'Partners Contacts'
end
