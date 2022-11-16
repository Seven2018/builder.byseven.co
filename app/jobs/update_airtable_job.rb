class UpdateAirtableJob < ApplicationJob
  include SuckerPunch::Job

  def perform(training, numbers_sevener = false, invoice_items = [])
    # return unless Rails.env.production?

    if numbers_sevener.present?
      # training.trainers.each{|y| training.export_numbers_sevener(y)}
      training.trainers.each do |trainer|

        ActiveRecord::Base.connection_pool.with_connection do
          training.export_numbers_sevener(trainer)
        end

      end
    end

    if invoice_items.present?
      invoice_items.each do |invoice_item|

        ActiveRecord::Base.connection_pool.with_connection do
          invoice_item.export_numbers_revenue
        end if invoice_item.type = 'Invoice'

      end
    else
      training.export_numbers_activity
    end

    training.export_airtable
  end
end
