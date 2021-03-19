class UpdateCumulationChartJob < ApplicationJob
  include SuckerPunch::Job

  def perform(date)
    Training.export_numbers_activity_cumulation(date)
  end
end
