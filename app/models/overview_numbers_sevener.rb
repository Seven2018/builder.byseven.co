Airrecord.api_key = Rails.application.credentials.airtable_key

class OverviewNumbersSevener < Airrecord::Table
  Rails.env.production? ? self.base_key = 'appGm0wPMcSxAI6RH' : self.base_key = 'appmHNAokYy761xK0'
  self.table_name = 'Numbers : Sevener'
end
