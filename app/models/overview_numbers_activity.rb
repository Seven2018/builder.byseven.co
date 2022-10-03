Airrecord.api_key = Rails.application.credentials.airtable_key

class OverviewNumbersActivity < Airrecord::Table
  self.base_key = 'appGm0wPMcSxAI6RH'
  self.table_name = 'Numbers : Activity'

  # ONLY FOR TEST PURPOSE
  # def self.test
  #   date_array = []
  #   i = 0
  #   sales = 0
  #   current_year = Date.today.year

  #   activities = OverviewNumbersActivity.all.select{|x| x['Date'] >= "#{current_year}-01-01" && x['Status (from Training)'] != ['12. Fail']}

  #   activities.each do |activity|
  #     activity['Revenue (Accumulation by Date)'] = nil
  #     activity['Revenue (Expected Accumulation by Date)'] = nil
  #     activity.save
  #   end

  #   date_array = activities.map{|x| x['Date']}.sort.uniq

  #   date_array.each do |date|
  #     date_records = OverviewNumbersActivity.all.select{|x| x['Date'] == date && x['Status (from Training)'] != ['12. Fail']}
  #     puts date
  #     sales = sales + date_records.map{|x|x['Revenue']}.sum
  #       date_records.first['Revenue (Accumulation by Date)'] = sales
  #       date_records.first['Revenue (Expected Accumulation by Date)'] = ((3000000.0 / 365) * (Date::strptime(date,'%Y-%m-%d') - Date.today.beginning_of_year)).round(2)
  #       date_records.first.save
  #     i += 1
  #   end
  # end
end
