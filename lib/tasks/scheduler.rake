desc "This task is called by the Heroku scheduler add-on"

task :send_reminders => :environment do
  Session.send_reminders
end

task :update_bizdev_data => :environment do
  User.report
end

task :update_cumulative_sales => :environment do
  Training.export_numbers_activity_cumulation
end
