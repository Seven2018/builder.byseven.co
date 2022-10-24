class UpdateAirtableJob < ApplicationJob
  include SuckerPunch::Job

  def perform(training, numbers_sevener = false, invoice_item = false)
    return unless Rails.env.production?

    if numbers_sevener.present?
      training.trainers.each{|y| training.export_numbers_sevener(y)}
    end

    if invoice_item.present?
      invoice_item.export_numbers_revenue if invoice_item.type = 'Invoice'
    else
      training.export_numbers_activity
    end

    training.export_airtable
  end
end
