class UpdateCumulationChartJob < ApplicationJob
  include SuckerPunch::Job

  def perform(date)
    date_array = []
    i = 0
    sales = 0
    date_array = OverviewNumbersActivity.all(filter: "{Date} >= '#{Date.today.beginning_of_year}'").map{|x| x['Date']}.sort.uniq
    date_array.each do |date|
      date_records = OverviewNumbersActivity.all.select{|x| x['Date'] == date}
      sales = sales + date_records.map{|x|x['Revenue']}.sum
        date_records.first['Revenue (Accumulation by Date)'] = sales
        date_records.first['Revenue (Expected Accumulation by Date)'] = ((3000000.0 / 365) * (Date::strptime(date,'%Y-%m-%d') - Date.today.beginning_of_year)).round(2)
        date_records.first.save
      i += 1
    end
  end
end
