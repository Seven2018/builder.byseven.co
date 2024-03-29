class InvoiceItem < ApplicationRecord
  default_scope {order(created_at: :asc)}

  belongs_to :client_company, optional: true
  belongs_to :training, optional: true
  belongs_to :user, optional: true
  has_one :session_trainers
  has_many :invoice_lines, dependent: :destroy
  validates_uniqueness_of :uuid
  self.inheritance_column = :_type_disabled

  paginates_per 25


  ###############
  ## PG_SEARCH ##
  ###############

  include PgSearch::Model
  pg_search_scope :search_invoices,
    against: [ :uuid ],
    associated_against: {
      client_company: [:name],
    },
    using: {
      tsearch: { prefix: true }
    },
    ignoring: :accents


  #############
  ## METHODS ##
  #############

  def self.to_csv
    attributes = %w(Date Journal Compte_Général Compte_Auxiliaire Référence Libellé Débit Crédit)
    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.each do |item|
        if item.type == 'Invoice'
          date = item.created_at.strftime('%d/%m/%Y')
          journal = 'VE'
          gen_account = '41100000'
          aux_account = item.client_company.reference
          invoice_num = item.uuid
          if item.client_company.client_company_type == 'School'
            company_label = "#{item.client_company.name}"
          else
            if item.training.present? && item.training.client_contact.billing_contact.present? && (item.client_company == item.training.client_company)
              company_label = "#{item.training.client_contact.billing_contact} TVA"
            else
              company_label = "#{item.client_company.name} TVA"
            end
          end
          debit = item.total_amount
          csv << [date, journal, gen_account, aux_account, invoice_num, company_label, debit, '']
          item.invoice_lines.each do |line|
            if line.product&.reference.present?
              credit = line&.net_amount * line&.quantity
              csv << [date, journal, line.product&.reference, '', invoice_num, company_label, '', credit]
            end
          end
          csv << [date, journal, '44571130', '', invoice_num, company_label, '', item.tax_amount] if item.tax_amount?
        end
      end
    end
  end

  def gross_revenue
    self.total_amount - self.tax_amount
  end

  def products
    self.invoice_lines.map(&:product)
  end

  def set_uuid
    if self.type == 'Invoice'

      self.uuid =
        if InvoiceItem.where(type: 'Invoice').count > 0
          "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
        else
          "FA#{Date.today.strftime('%Y')}00001"
        end

    else

      self.uuid =
        if InvoiceItem.where(type: 'Estimate').count > 0
          "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
        else
          "DE#{Date.today.strftime('%Y')}00001"
        end

    end
  end

  # Exports the data to Airtable DB
  def export_numbers_revenue
    # begin
      return if self.type != 'Invoice'
      training = OverviewTraining.all(filter: "{Builder_id} = '#{self.training_id}'")&.first if self.training.present?
      invoice = OverviewNumbersRevenue.all(filter: "{Invoice_id} = '#{self.id}'")&.first

      unless invoice.present?
        if training.present?
          invoice = OverviewNumbersRevenue.create('Training' => [training&.id], 'Invoice SEVEN' => self.uuid, 'Issue Date' => Date.today.strftime('%Y-%m-%d'), 'Invoice_id' => self.id)
        else
          invoice = OverviewNumbersRevenue.create('Invoice SEVEN' => self.uuid, 'Issue Date' => Date.today.strftime('%Y-%m-%d'), 'Invoice_id' => self.id)
        end
      end

      invoice['Training'] = [training&.id]

      lines = []
      if self.products.include?(Product.find(1))
        lines = self.invoice_lines.select{|x| x.product_id == 1}
      elsif self.products.include?(Product.find(2))
        lines = self.invoice_lines.select{|x| x.product_id == 2}
      elsif self.products.include?(Product.find(7))
        lines = self.invoice_lines.select{|x| x.product_id == 7}
      elsif self.products.include?(Product.find(9))
        lines = self.invoice_lines.select{|x| x.product_id == 9}
      else
        invoice['Unit Number'] = 0
      end

      lines.present? ? invoice['Unit Price'] = (lines.map{|x| x.net_amount * x.quantity}.sum / lines.map(&:quantity).sum).to_f : invoice['Unit Price'] = 0
      invoice['Unit Number'] = lines.map{|x| x&.quantity}&.sum

      if self.products.include?(Product.find(3))
        lines = self.invoice_lines.select{|x| x.product_id == 3}
        invoice['Preparation'] = lines.map{|x| x.net_amount * x.quantity}.sum.to_f
      else
        invoice['Preparation'] = nil
      end

      if self.products.include?(Product.find(8))
        lines = self.invoice_lines.select{|x| x.product_id == 8}
        invoice['Deposit'] = lines.map{|x| x.net_amount * x.quantity}.sum.to_f
      end

      expenses = self.products.compact.select{|x| [4,5,6].include?(x.id)}
      if expenses.present?
        lines = self.invoice_lines.select{|x| expenses.include?(x.product)}
        invoice['Billed Expenses'] = lines.map{|x| x.net_amount * x.quantity}.sum.to_f
      else
        invoice['Billed Expenses'] = nil
      end

      self.update_price
      invoice['VAT'] = self.tax_amount.to_f
      invoice['OPCO'] = self.client_company.name if self.client_company.client_company_type == 'OPCO'
      invoice['Training_id'] = self.training.id if training.present?
      if self.payment_date.present?
        invoice['Paid'] = true
        invoice['Payment Date'] = self.payment_date.strftime('%Y-%m-%d')
      else
        invoice['Paid'] = false
      end
      if self.sending_date.present?
        invoice['Sending Date'] = self.sending_date.strftime('%Y-%m-%d')
      end
      if self.status == "Cancelled"
        invoice['Type'] = 'Cancelled'
      elsif self.status == "Credit"
        invoice['Type'] = 'Credit'
      elsif self.products.include?(Product.find(7))
        invoice['Type'] = 'Home'
      elsif self.products.include?(Product.find(8))
        invoice['Type'] = 'Deposit (Home)'
      else
        invoice['Type'] = 'Training'
      end
      self.training.export_airtable if training.present?
      invoice.save
    # rescue
    # end
  end

  # Updates InvoiceItem price and tax amount
  def update_price
    total = 0
    tax = 0
    self.invoice_lines.each do |line|
      if !line.quantity.nil? && !line.net_amount.nil? && !line.tax_amount.nil?
        total += line.quantity * line.net_amount * (1 + line.tax_amount/100)
        tax += line.quantity * line.net_amount * (line.tax_amount/100)
      end
    end
    self.update(total_amount: total, tax_amount: tax)
    self.save
  end

  def self.account_invoice
    AccountInvoice.all.each{|x| x.destroy}
    InvoiceItem.where('created_at > ?', Date::strptime('2021-01-01', '%Y-%m-%d')).each do |invoice|
      if invoice.payment_date.present?
        acc_invoice = AccountInvoice.create('Numéro' => invoice.uuid, 'Destinataire' => invoice.client_company.name, 'Montant TTC' => invoice.total_amount.to_f, 'Date Paiement' => invoice.payment_date.strftime('%Y-%m-%d'))
        acc_invoice.save
      end
    end
  end
end
