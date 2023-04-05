class AccessToken
  attr_reader :token
  def initialize(token)
    @token = token
  end

  def apply!(headers)
    headers['Authorization'] = "Bearer #{@token}"
  end
end

class InvoiceItemsController < ApplicationController
  before_action :set_invoice_item, only: [:show, :edit, :update, :copy, :transform_to_invoice, :edit_client, :credit, :marked_as_send, :marked_as_paid, :marked_as_cancelled, :destroy]

  ##########
  ## CRUD ##
  ##########

  # Indexes with a filter option (see below)
  def index
    if (params[:export].present? && params[:export][:type].present?)
      @invoice_items = policy_scope(InvoiceItem).where(created_at: params[:export][:start_date]..params[:export][:end_date], type: params[:export][:type]).order(:uuid)
    else
      if params[:training_id].present?
        @invoice_items = policy_scope(InvoiceItem).where(training_id: params[:training_id].to_i, type: params[:type])
      elsif params[:client_company_id].present?
        @invoice_items = policy_scope(InvoiceItem).where(client_company_id: params[:client_company_id].to_i, type: params[:type])
      elsif params[:client_company_id].nil?
        @invoice_items = policy_scope(InvoiceItem).where(type: params[:type])
      end

      search_invoice = params.dig(:search, :reference)&.downcase
      page_index = (params.dig(:search, :page).presence || 1).to_i

      @invoice_items = @invoice_items.where("lower(uuid) LIKE ?", "%#{search_invoice}%").or(@invoice_items.where_exists(:client_company, "lower(name) LIKE ?", "%#{search_invoice}%")) if search_invoice.present?
      @total_invoices = @invoice_items.count
      @invoice_items = @invoice_items.order(created_at: :desc).page(page_index)
      @any_more = @invoice_items.count * page_index < @total_invoices
    end

    respond_to do |format|
      format.html
      format.js
      format.csv { send_data @invoice_items.to_csv, filename: "Factures SEVEN #{params[:export][:start_date].split('-').join('')} - #{params[:export][:end_date].split('-').join('')}.csv" }
    end
  end

  # Shows an InvoiceItem in html or pdf version
  def show
    authorize @invoice_item

    set_invoice_item_text

    respond_to do |format|
      format.html
      format.pdf do
        render(
          pdf: "#{@invoice_item.uuid}",
          layout: 'pdf.html.erb',
          margin: { bottom: 45, top: 62 },
          header: { margin: { top: 0, bottom: 0 }, html: { template: 'invoice_items/header.pdf.erb' } },
          footer: { margin: { top: 0, bottom: 0 }, html: { template: 'invoice_items/footer.pdf.erb' } },
          template: 'invoice_items/show',
          background: true,
          show_as_html: params.key?('debug'),
          page_size: 'A4',
          encoding: 'utf8',
          dpi: 300,
          zoom: 1
        )
      end
    end
  end

  def update
    authorize @invoice_item

    @invoice_item.update(invoice_item_params)
    @invoice_item.client_company_id = @invoice_item.training.client_company.id if params[:invoice_item][:training_id].present?

    if @invoice_item.save
      unless params.dig(:invoice_item, :skip_update).present?
        UpdateAirtableJob.perform_async(@invoice_item.training, false, [@invoice_item]) if @invoice_item.type == 'Invoice'
      end

      respond_to do |format|
        format.html { redirect_to invoice_item_path(@invoice_item) }
        format.js
      end
    end
  end

  # Access to InvoiceItems
  def report
    @invoice_items = InvoiceItem.all
    authorize @invoice_items
  end

  # Creates a new InvoiceItem, proposing a pre-filled version to be edited if necessary
  def new_invoice_item
    @training = Training.find(params[:training_id])
    @client_company = ClientCompany.find(params[:client_company_id])
    @invoice = InvoiceItem.new(training_id: params[:training_id].to_i, client_company_id: params[:client_company_id].to_i, type: params[:type])
    authorize @invoice

    @invoice.set_uuid

    @invoice.status = 'Pending'
    @invoice.object = @training.client_company.name + ' - ' + @training.title

    # Fills the created InvoiceItem with InvoiceLines, according Training data
    if @training.client_contact.client_company.client_company_type == 'Company'
      product = Product.find(2)
      quantity = 0

      @training.sessions.each do |session|
        session.duration < 4 ? quantity += 0.5 * session.session_trainers.count : quantity += 1 * session.session_trainers.count
      end
    else
      product = Product.find(1)
      quantity = 0

      @training.sessions.each do |session|
        quantity += session.duration
      end
    end

    InvoiceLine.create(invoice_item: @invoice, description: "Animation", quantity: quantity, net_amount: product.price, tax_amount: product.tax, product_id: product.id, position: 1)
    @invoice.update_price

    if @invoice.save
      UpdateAirtableJob.perform_async(@training, false, [@invoice])
      redirect_to invoice_item_path(@invoice)
    end
  end

  # Destroys an InvoiceItem
  def destroy
    authorize @invoice_item
    @invoice_item.destroy
    redirect_to client_company_path(@invoice_item.client_company)
  end


  ##############
  ## AIRTABLE ##
  ##############

  def airtable_update_invoice
    invoice = OverviewNumbersRevenue.find(params[:record_id])
    builder_invoice = InvoiceItem.find_by(id: invoice['Invoice_id'])
    skip_authorization

    if invoice['Type'] == 'To Delete'
      begin
        if builder_invoice.nil?
          flash[:alert] = "Invoice #{invoice['Invoice SEVEN']} not found."
        else
          builder_invoice.destroy
          flash[:notice] = "Invoice #{builder_invoice.uuid} successfully deleted."
        end
      rescue
          flash[:alert] = "A problem has occured. Please contact your administrator."
      end

      redirect_to invoice_items_path(type: 'Invoice', page: 1)
    end
  end

  # Creates a new InvoiceItem using data from Airtable DB
  def new_airtable_invoice_item
    skip_authorization

    @training = Training.find(params[:training_id])

    airtable_training = OverviewTraining.all(filter: "{Reference SEVEN} = '#{@training.refid}'").first
    @client_company = ClientCompany.find(params[:client_company_id])
    @invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: params[:type])

    @invoice.object = @training.client_company.name + ' - ' + @training.title
    @invoice.status = 'Pending'
    @invoice.set_uuid

    # Fills the created InvoiceItem with InvoiceLines, according Training data
    @training.client_contact.client_company.client_company_type == 'Company' ? product = Product.find(2) : product = Product.find(1)
    line = InvoiceLine.new(invoice_item: @invoice, description: "Animation", quantity: airtable_training['Unit Number'], net_amount: airtable_training['Unit Price'], tax_amount: product.tax, product_id: product.id, position: 1)
    comments = "<br>Détail des séances (date, horaires, intervenant(s)) :<br><br>"

    @training.sessions.each do |session|
      lunch = session.workshops.find_by(title: 'Pause Déjeuner')

      if lunch.present?
        morning = session.workshops.where('position < ?', lunch.position)
        afternoon = session.workshops.where('position > ?', lunch.position)
        comments += "- Le #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{(session.start_time+morning.map(&:duration).sum.minutes).strftime('%Hh%M')} et de #{(session.end_time-afternoon.map(&:duration).sum.minutes).strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')} : #{session.users.map{|x|x.fullname}.join(', ')} (#{session.duration} h)<br>" if session.date.present?
      else
        comments += "- Le #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')} : #{session.users.map{|x|x.fullname}.join(', ')} (#{session.duration} h)<br>" if session.date.present?
      end
    end

    line.comments = comments
    line.save

    if airtable_training['Preparation'].present? && airtable_training['Preparation'] != 0
      preparation = Product.find(3)
      InvoiceLine.create(invoice_item: @invoice, description: 'Préparation formation', quantity: 1, net_amount: airtable_training['Preparation'], tax_amount: preparation.tax, product_id: preparation.id, position: 2)
    end

    @invoice.update_price

    if @invoice.save
      UpdateAirtableJob.perform_async(@training, false, [@invoice])

      redirect_to invoice_item_path(@invoice)
    end
  end

  # Creates new InvoiceItems using data from Airtable DB for each trainer
  def new_airtable_invoice_item_by_trainer
    skip_authorization

    @training = Training.find(params[:training_id])

    airtable_training = OverviewTraining.all.select{|x|x['Reference SEVEN'] == @training.refid}.first
    @client_company = ClientCompany.find(params[:client_company_id])

    @training.trainers.each do |trainer|
      new_invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: 'Invoice')
      new_invoice.set_uuid
      comments = "<br>Intervenant(e) : #{trainer.fullname}<br><br>Détail des séances (date, horaires) :<br>"
      quantity = 0

      @training.sessions.joins(:session_trainers).where(session_trainers: {user_id: trainer.id}).each do |session|
        lunch = session.workshops.find_by(title: 'Pause Déjeuner')

        if lunch.present?
          morning = session.workshops.where('position < ?', lunch.position)
          afternoon = session.workshops.where('position > ?', lunch.position)
          comments += "- Le #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{(session.start_time+morning.map(&:duration).sum.minutes).strftime('%Hh%M')} et de #{(session.end_time-afternoon.map(&:duration).sum.minutes).strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')} (#{session.duration} h)<br>" if session.date.present?
        else
          comments += "- Le #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')} (#{session.duration} h)<br>" if session.date.present?
        end

        if airtable_training['Unit Type'] == 'Half day'
          session.workshops.find_by(title: 'Pause Déjeuner').present? ? quantity += 1 : quantity += 0.5
        elsif airtable_training['Unit Type'] == 'Hour'
          quantity += session.duration
        end
      end

      @training.client_contact.client_company.client_company_type == 'Company' ? product = Product.find(2) : product = Product.find(1)
      new_line = InvoiceLine.new(invoice_item: new_invoice, description: @training.client_company.name + ' - ' + @training.title, quantity: quantity, net_amount: airtable_training['Unit Price'], tax_amount: product.tax, product_id: product.id, position: 1)
      new_line.comments = comments

      new_line.save
      new_invoice.save

      new_invoice.update_price

      UpdateAirtableJob.perform_async(@training, false, [new_invoice])
    end

    redirect_to invoice_items_path(type: 'Invoice', training_id: @training.id)
  end

  # Creates new InvoiceItems using data from Airtable DB for each attendee
  def new_airtable_invoice_item_by_attendee
    skip_authorization

    @training = Training.find(params[:training_id])
    airtable_training = OverviewTraining.all.select{|x|x['Reference SEVEN'] == @training.refid}.first

    if airtable_training['Unit Type'] == 'Participant'
      @client_company = ClientCompany.find(params[:client_company_id])

      new_invoices = []

      @training.attendees.each do |attendee|
        new_invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: 'Invoice')
        new_invoice.set_uuid
        comments = "<br>Participant(e) : #{attendee.fullname}<br><br>Détail des séances (date, horaires) :<br>"

        @training.sessions.each do |session|
          if session.session_attendees.where(attendee_id: attendee.id).present?
            lunch = session.workshops.find_by(title: 'Pause Déjeuner')

            if lunch.present?
              morning = session.workshops.where('position < ?', lunch.position)
              afternoon = session.workshops.where('position > ?', lunch.position)
              comments += "- Le #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{(session.start_time+morning.map(&:duration).sum.minutes).strftime('%Hh%M')} et de #{(session.end_time-afternoon.map(&:duration).sum.minutes).strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')} (#{session.duration} h)<br>" if session.date.present?
            else
              comments += "- Le #{session.date.strftime('%d/%m/%Y')} de #{session.start_time.strftime('%Hh%M')} à #{session.end_time.strftime('%Hh%M')} (#{session.duration} h)<br>" if session.date.present?
            end
          end
        end

        @training.client_contact.client_company.client_company_type == 'Company' ? product = Product.find(2) : product = Product.find(1)
        new_line = InvoiceLine.new(invoice_item: new_invoice, description: @training.client_company.name + ' - ' + @training.title, quantity: 1, net_amount: airtable_training['Unit Price'], tax_amount: product.tax, product_id: product.id, position: 1)
        new_line.comments = comments

        new_line.save
        new_invoice.save

        new_invoice.update_price

        new_invoices << new_invoice
      end
    end

    UpdateAirtableJob.perform_async(@training, false, new_invoices)

    redirect_to invoice_items_path(type: 'Invoice', training_id: @training.id)
    flash[:alert] = "This training unit type is not defined as 'Participant' in Airtable." unless airtable_training['Unit Type'] == 'Participant'
  end


  ##########
  ## MISC ##
  ##########

  # Creates a new estimate
  def new_estimate
    @client_company = ClientCompany.find(params[:client_company_id])
    @estimate = InvoiceItem.new(client_company_id: params[:client_company_id].to_i, type: 'Estimate')
    authorize @estimate

    @estimate.set_uuid

    if @estimate.save
      if @client_company.client_company_type == 'Company'
        product = Product.find(2)
        InvoiceLine.create(invoice_item: @estimate, description: product.name, quantity: 0, net_amount: product.price, tax_amount: product.tax, position: 1, product_id: 2)
      elsif @client_company.client_company_type == 'School'
        product = Product.find(1)
        quantity = 0
        InvoiceLine.create(invoice_item: @estimate, description: product.name, quantity: 0, net_amount: product.price, tax_amount: product.tax, position: 1, product_id: 1)
      end

      @estimate.update_price

      redirect_to invoice_item_path(@estimate)
    end
  end

  def copy
    authorize @invoice_item

    training = Training.find_by(id: params[:copy][:target_training_id])
    company = ClientCompany.find_by(id: params[:copy][:target_client_company_id])
    new_invoices = []

    for i in 1..params[:copy][:amount].to_i
      new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "training_id", "client_company_id", "status", "sending_date", "payment_date", "dunning_date"))

      if training.present?
        new_invoice_item.training_id = training.id
        new_invoice_item.client_company_id = training.client_company.id
      else
        new_invoice_item.client_company_id = company.id
      end

      new_invoice_item.set_uuid

      if training.present?
        new_invoice_item.status = @invoice_item.status == 'Credit' ? 'Credit' : 'Pending'
      end

      new_invoice_item.save

      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: new_invoice_item.id)
      end

      new_invoice_item.update_price
      new_invoices << new_invoice_item if new_invoice_item.type == 'Invoice'
    end

    UpdateAirtableJob.perform_async(new_invoice_item.training, false, new_invoices)

    redirect_to invoice_items_path(page: 1, type: @invoice_item.type)
  end

  #Transforms an estimate into an invoice
  def transform_to_invoice
    authorize @invoice_item

    new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "sending_date", "payment_date", "dunning_date"))
    new_invoice_item.status = 'Pending'
    new_invoice_item.type = 'Invoice'
    new_invoice_item.set_uuid

    new_invoice_item.save

    @invoice_item.invoice_lines.each do |line|
      new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
      new_invoice_line.update(invoice_item_id: new_invoice_item.id)
    end

    new_invoice_item.update_price

    UpdateAirtableJob.perform_async(new_invoice_item.training, false, [new_invoice_item]) if new_invoice_item.training.present?

    unless new_invoice_item.valid?
      puts "can't create training"
      puts new_invoice_item
      puts new_invoice_item.errors.messages
    end
    redirect_to invoice_item_path(new_invoice_item)
  end

  # Allows to change the ClientCompany of an InvoiceItem (OPCO cases)
  def edit_client
    authorize @invoice_item
    company = ClientCompany.find(params[:client_company_id])

    if company.client_company_type == 'Company'
      @invoice_item.update(client_company_id: company.opco_id, description: "#{company.id}")
    elsif company.client_company_type == 'OPCO'
      @invoice_item.update(client_company_id: @invoice_item.description.to_i, description: nil)
    end

    redirect_to invoice_item_path(@invoice_item)
  end

  # Creates a credit
  def credit
    authorize @invoice_item
    credit = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at"))
    credit.set_uuid

    credit.save

    @invoice_item.invoice_lines.each do |line|
      new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
      new_invoice_line.update(invoice_item_id: credit.id)
      new_invoice_line.update(net_amount: -(line.net_amount)) if line.net_amount.present?
    end

    credit.update(total_amount: -@invoice_item.total_amount)
    credit.update(status: "Credit") if credit.total_amount < 0

    UpdateAirtableJob.perform_async(credit.training, false, [credit]) if credit.training.present?

    redirect_to invoice_item_path(credit)
  end

  # Marks an InvoiceItem as send
  def marked_as_send
    authorize @invoice_item

    @invoice_item.update(sending_date: params[:edit_sending][:sending_date], status: 'Sent')

    UpdateAirtableJob.perform_async(@invoice_item.training, false, [@invoice_item])

    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  # Marks an InvoiceItem as paid
  def marked_as_paid
    authorize @invoice_item

    @invoice_item.update(payment_date: params[:edit_payment][:payment_date], status: 'Paid')

    UpdateAirtableJob.perform_async(@invoice_item.training, false, [@invoice_item])

    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  # Marks an InvoiceItem as reminded
  def marked_as_reminded
    authorize @invoice_item

    @invoice_item.update(dunning_date: params[:edit_payment][:dunning_date])

    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  #Marks an InvoiceItem as cancelled
  def marked_as_cancelled
    authorize @invoice_item

    @invoice_item.update(status: "Cancelled")

    UpdateAirtableJob.perform_async(@invoice_item.training, false, [@invoice_item])

    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  def send_invoice_mail
    raise
    # TO DO
  end


  private

  def set_invoice_item
    @invoice_item = InvoiceItem.find(params[:id])
  end

  def invoice_item_params
    params.require(:invoice_item).permit(:training_id, :client_company_id, :status, :uuid, :object)
  end

  def set_invoice_item_text
    @text = {'fr' => { 'invoice' => 'Facture',
              'established' => 'Établie en euro',
              'designation' => 'Désignation',
              'quantity' => 'Qté',
              'unit_price' => 'PU HT',
              'subtotal' => 'Montant HT',
              'vat' => 'TVA',
              'net_subtotal' => 'Total HT Net',
              'total_vat' => 'Total TVA',
              'total' => 'Total TTC',
              'net_total' => 'Net à payer en EUR',
              'due_date' => 'Echéance(s)',
              'amount' => 'Montant',
              'bank_statement1' => "Déclaration d'activité sous le numéro 11 92 20487 92 auprès du Préfet d'IDF",
              'bank_statement2' => "Domiciliation Bancaire : CIC Paris République",
              'bank_statement3' => "Banque : 3006 Guichet : 10011 N° Compte : 00020287201 Clé : 36",
              'info' => "Pas d'escompte pour paiement anticipé, passée la date d'échéance, tout paiement différé entraîne l'application d'une pénalité de 3 fois le taux d'intérêt légal (loi 2008-776 du 04/08/2008) ainsi qu'une indemnité forfaitaire pour frais de recouvrement de 40 euros (Décret 2012-1115 du 02/10/2012)."
                    },
              'en' => { 'invoice' => 'Invoice',
                'established' => 'Established in euro',
                'designation' => 'Description',
                'quantity' => 'Qty',
                'unit_price' => 'Unit Price',
                'subtotal' => 'Subtotal',
                'vat' => 'VAT',
                'net_subtotal' => 'Subtotal',
                'total_vat' => 'VAT',
                'total' => 'Total',
                'net_total' => 'Total Net Price',
                'due_date' => 'Due date',
                'amount' => 'Amount',
                'bank_statement1' => "Declaration of activity under number 11 92 20487 92 with the Prefect of IDF",
                'bank_statement2' => "Bank address: CIC Paris République",
                'bank_statement3' => "Bank: 3006 Box: 10011 Account number: 00020287201 Key: 36",
                'info' => "No discount for early payment, after the due date, any deferred payment will result in the application of a penalty of 3 times the legal interest rate (law 2008-776 of 04/08/2008) as well as a fixed indemnity for collection costs of 40 euros (Decree 2012-1115 of 02/10/2012)."
                      }
            }
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << column_names

      all.each do |result|
        csv << result.attributes.values_at(*column_names)
      end
    end
  end
end

