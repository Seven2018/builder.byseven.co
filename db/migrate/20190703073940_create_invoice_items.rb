class CreateInvoiceItems < ActiveRecord::Migration[5.2]
  def change
    create_table :invoice_items do |t|
      t.references :client_company, foreign_key: true
      t.references :training, foreign_key: true
      t.references :user, foreign_key: true
      t.string :type
      t.decimal :total_amount, precision: 15, scale: 10
      t.decimal :tax_amount, precision: 15, scale: 10
      t.string :status
      t.string :description
      t.datetime :sending_date
      t.datetime :payment_date
      t.string :uuid

      t.timestamps
    end
  end
end
