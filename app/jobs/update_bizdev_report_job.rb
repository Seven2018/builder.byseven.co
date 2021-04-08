class UpdateBizdevReportJob < ApplicationJob
  include SuckerPunch::Job

  def perform(date = Date.today)
    week = "Week #{date.strftime("%U").to_i}"
    OverviewUser.all.select{|x| x['Status'] == 'SEVEN'}.each do |user|
      ownership_hours_ongoing = OverviewTraining.all.select{|x| x['Owner'].present? && x['Owner'].join == user.id}.select{|x| x['Due Date'].present? && Date::strptime(x['Due Date'],'%Y-%m-%d') >= date.beginning_of_week}.map{|x| if x['Hours'].present?; x['Hours']; end}.sum
      project_hours_dev = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id}.map{|z| z['Hours'].to_i}.sum
      project_hours_codev = OverviewProject.all.select{|x| x['Co-developer'].present? && x['Co-developer'].join == user.id}.map{|z| z['Hours'].to_i}.sum
      training_hours = User.find(user['Builder_id']).hours_this_week(date)
      projects_1 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '1 - Prospect(s) : person or/and company'}.count
      projects_2 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '2 - Identified contact lead'}.count
      projects_3 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '3 - Handshaked contact lead'}.count
      projects_4 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '4 - Strong relationship lead'}.count
      projects_5 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '5 - Needs identified lead'}.count
      projects_6 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '6 - Pre-Signed lead'}.count
      projects_7 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '7 - Signed lead'}.count
      memo_count = 0.0
      OverviewMemo.all.select{|x| x['Users'].present? && x['Users'].include?(user.id) && Date::strptime(x['Date'], "%Y-%m-%d") >= date.beginning_of_week}.each do |memo|
        memo_count += (1.0 / memo['Users'].count)
      end
      memo_count = (memo_count * 2.0).round / 2.0
      data_hash = {Ongoing_Ownership:  ownership_hours_ongoing.to_s, Project_Hours_Dev: project_hours_dev.to_s, Project_Hours_Codev: project_hours_codev.to_s, '1 - Prospect' => projects_1.to_s, '2 - Identified contact' => projects_2.to_s, '3 - Handshaked contact' => projects_3.to_s, '4  - Strong relationship' => projects_4.to_s, '5 - Needs identified' => projects_5.to_s, '6 - Pre-signed' => projects_6.to_s, '7 - Signed' => projects_7.to_s, Weekly_Memos: memo_count.to_s, Trained_Hours: training_hours.to_s}
      data_hash.each do |key, value|
        line = OverviewBizdev.all.select{|x| x['User'] == user['Name'] && x['Data'] == key.to_s}.first
        if !line.present?
          line = OverviewBizdev.create('User' => user['Name'], 'Data' => key, week => value)
        else
          line[week] = value
        end
        line.save
      end
      OverviewDataStudio.create('Date' => date.beginning_of_week, 'User' => user['Name'], 'Ongoing Ownership (hours)' => ownership_hours_ongoing, 'Project Hours (Dev)' => project_hours_dev, 'Project Hours (co-Dev)' => project_hours_codev, 'Trained Hours (this week)' => training_hours, 'Memos' => memo_count, '1 - Prospect' => projects_1, '2 - Identified contact' => projects_2, '3 - Handshaked contact' => projects_3, '4  - Strong relationship' => projects_4, '5 - Needs identified' => projects_5, '6 - Pre-signed' => projects_6, '7 - Signed' => projects_7)
    end
  end
end
