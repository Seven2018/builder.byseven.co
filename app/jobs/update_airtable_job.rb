class UpdateAirtableJob < ApplicationJob
  include SuckerPunch::Job

  def perform(training, numbers_sevener = false, invoice_item = false)
    # if numbers_sevener.present?
    #   training.trainers.each{|y| training.export_numbers_sevener(y)}
    # end
    # if invoice_item.present?
    #   invoice_item.export_numbers_revenue if invoice_item.type = 'Invoice'
    # end
    # training.export_airtable
    # training.export_numbers_activity
  end
end
