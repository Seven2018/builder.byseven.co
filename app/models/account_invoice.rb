Airrecord.api_key = Rails.application.credentials.airtable_key

class AccountInvoice < Airrecord::Table
  self.base_key = 'appuVKlwL05XcpVS6'
  self.table_name = 'Factures'
end
