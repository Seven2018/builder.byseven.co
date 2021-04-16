class AddObjectToInvoiceitem < ActiveRecord::Migration[6.0]
  def change
    add_column :invoice_items, :object, :string, :default => ''
    add_column :client_companies, :siret, :string, :default => ''
  end
end
