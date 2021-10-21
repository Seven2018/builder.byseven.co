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

  # Indexes with a filter option (see below)
  def index
    @invoice_items = policy_scope(InvoiceItem)
    unless params[:export].present?
      index_filtered(params[:page].to_i)
    end
    if params[:search]
      @invoice_items = @invoice_items_total = ((InvoiceItem.where(type: params[:type]).where("lower(uuid) LIKE ?", "%#{params[:search][:reference].downcase}%")) + (InvoiceItem.joins(:client_company).where(type: params[:type]).where("lower(client_companies.name) LIKE ?", "%#{params[:search][:reference].downcase}%"))).flatten(1).uniq
    end
    @invoice_items = InvoiceItem.where(created_at: params[:export][:start_date]..params[:export][:end_date], type: params[:export][:type]).order(:uuid) if (params[:export].present? && params[:export][:type].present?)
    respond_to do |format|
      format.html
      format.csv { send_data @invoice_items.to_csv, filename: "Factures SEVEN #{params[:export][:start_date].split('-').join('')} - #{params[:export][:end_date].split('-').join('')}.csv" }
    end
  end

  # Shows an InvoiceItem in html or pdf version
  def show
    authorize @invoice_item
    if @invoice_item.invoice_lines.where(description: 'Nom').present?
      uuid = @invoice_item.uuid + ' - ' + @invoice_item.invoice_lines.where(description: 'Nom').first.comments.split('>')[1].split('<')[0]
    else
      uuid = @invoice_item.uuid
    end
    respond_to do |format|
      format.html
      format.pdf do
        render(
          pdf: "#{uuid}",
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

  def edit
    authorize @invoice_item
  end

  def update
    authorize @invoice_item
    @invoice_item.update(invoiceitem_params)
    if @invoice_item.save
      unless params[:invoice_item][:skip_update].present?
        @invoice_item.export_numbers_revenue
      end
      redirect_to invoice_item_path(@invoice_item)
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
    invoices = InvoiceItem.where(type: 'Invoice')
    estimates = InvoiceItem.where(type: 'Estimate')
    # attributes a invoice number to the InvoiceItem
    if params[:type] == 'Invoice'
      invoices.count != 0 ? (@invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (invoices.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
    elsif params[:type] == 'Estimate'
      estimates.count != 0 ? (@invoice.uuid = "DE#{Date.today.strftime('%Y')}" + (estimates.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "DE#{Date.today.strftime('%Y')}00001")
    end
    @invoice.status = 'Pending'
    @invoice.object = @training.client_company.name + ' - ' + @training.title
    # Fills the created InvoiceItem with InvoiceLines, according Training data
    if @training.client_contact.client_company.client_company_type == 'Company'
      product = Product.find(2)
      quantity = 0
      @training.sessions.each do |session|
        session.duration < 4 ? quantity += 0.5 * session.session_trainers.count : quantity += 1 * session.session_trainers.count
      end
      # InvoiceLine.create(invoice_item: @invoice, description: @training.title, quantity: quantity, net_amount: product.price, tax_amount: product.tax, product_id: product.id, position: 1)
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
      # UpdateAirtableJob.perform_async(@training, false, @invoice)
      redirect_to invoice_item_path(@invoice)
    end
  end

  # Creates a new InvoiceItem using data from Airtable DB
  def new_airtable_invoice_item
    @training = Training.find(params[:training_id])
    # airtable_training = OverviewTraining.all.select{|x|x['Reference SEVEN'] == @training.refid}.first
    airtable_training = OverviewTraining.all(filter: "{Reference SEVEN} = '#{@training.refid}'").first
    @client_company = ClientCompany.find(params[:client_company_id])
    @invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: params[:type])
    skip_authorization
    invoices = InvoiceItem.where(type: 'Invoice')
    estimates = InvoiceItem.where(type: 'Estimate')
    @invoice.object = @training.client_company.name + ' - ' + @training.title
    # attributes a invoice number to the InvoiceItem
    if params[:type] == 'Invoice'
      invoices.count != 0 ? (@invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (invoices.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
    elsif params[:type] == 'Estimate'
      estimates.count != 0 ? (@invoice.uuid = "DE#{Date.today.strftime('%Y')}" + (estimates.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "DE#{Date.today.strftime('%Y')}00001")
    end
    @invoice.status = 'Pending'
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
      # UpdateAirtableJob.perform_async(@training, false, @invoice)
      redirect_to invoice_item_path(@invoice)
    end
  end

  # Creates new InvoiceItems using data from Airtable DB for each trainer
  def new_airtable_invoice_item_by_trainer
    skip_authorization
    @training = Training.find(params[:training_id])
    airtable_training = OverviewTraining.all.select{|x|x['Reference SEVEN'] == @training.refid}.first
    @client_company = ClientCompany.find(params[:client_company_id])
    invoices = InvoiceItem.where(type: 'Invoice')
    @training.trainers.each do |trainer|
      new_invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: 'Invoice')
      invoices.count != 0 ? (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (invoices.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
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
      # UpdateAirtableJob.perform_async(@training, false, new_invoice)
    end
    redirect_to invoice_items_path(type: 'Invoice', training_id: @training.id)
  end

  # Creates new InvoiceItems using data from Airtable DB for each attendee
  def new_airtable_invoice_item_by_attendee
    skip_authorization
    @training = Training.find(params[:training_id])
    airtable_training = OverviewTraining.all.select{|x|x['Reference SEVEN'] == @training.refid}.first
    invoices = InvoiceItem.where(type: 'Invoice')
    if airtable_training['Unit Type'] == 'Participant'
      @client_company = ClientCompany.find(params[:client_company_id])
      @training.attendees.each do |attendee|
        new_invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: 'Invoice')
        invoices.count != 0 ? (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (invoices.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
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
        # UpdateAirtableJob.perform_async(@training, false, new_invoice)
      end
    end
    redirect_to invoice_items_path(type: 'Invoice', training_id: @training.id)
    flash[:alert] = "This training unit type is not defined as 'Participant' in Airtable." unless airtable_training['Unit Type'] == 'Participant'
  end

  # Creates a new estimate
  def new_estimate
    @client_company = ClientCompany.find(params[:client_company_id])
    @estimate = InvoiceItem.new(client_company_id: params[:client_company_id].to_i, type: 'Estimate')
    authorize @estimate
    estimates = InvoiceItem.where(type: 'Estimate')
    estimates.count != 0 ? (@estimate.uuid = "DE#{Date.today.strftime('%Y')}" + (estimates.last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@estimate.uuid = "DE#{Date.today.strftime('%Y')}00001")
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
    if params[:copy_here].present?
      new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "sending_date", "payment_date", "dunning_date"))
    else
      @training = Training.find(params[:copy][:training_id]) if params[:copy][:training_id].present?
      new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "training_id", "client_company_id", "status", "sending_date", "payment_date", "dunning_date"))
      new_invoice_item.training_id = @training.id if @training.present?
      new_invoice_item.client_company_id = params[:copy][:client_company_id]
    end
    if @invoice_item.type == 'Invoice'
      new_invoice_item.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    else
      new_invoice_item.uuid = "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    end
    new_invoice_item.status = 'Pending'
    if new_invoice_item.save
      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: new_invoice_item.id)
      end
      new_invoice_item.update_price
      # UpdateAirtableJob.perform_async(@new_invoice.training, false, new_invoice) if new_invoice_item.type == 'Invoice'
      redirect_to invoice_item_path(new_invoice_item)
    else
      raise
    end
  end

  #Transforms an estimate into an invoice
  def transform_to_invoice
    authorize @invoice_item
    new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "sending_date", "payment_date", "dunning_date"))
    new_invoice_item.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    new_invoice_item.status = 'Pending'
    new_invoice_item.type = 'Invoice'
    if new_invoice_item.save
      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: new_invoice_item.id)
      end
      new_invoice_item.update_price
      # UpdateAirtableJob.perform_async(new_invoice_item.training, false, new_invoice_item) if new_invoice_item.training.present?
      redirect_to invoice_item_path(new_invoice_item)
    else
      raise
    end
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
    credit.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    if credit.save
      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: credit.id)
        new_invoice_line.update(net_amount: -(line.net_amount)) if line.net_amount.present?
      end
      credit.update(total_amount: -@invoice_item.total_amount)
      credit.update(status: "Credit") if credit.total_amount < 0
      # UpdateAirtableJob.perform_async(credit.training, false, credit) if credit.training.present?
      redirect_to invoice_item_path(credit)
    else
      raise
    end
  end

  # Destroys an InvoiceItem
  def destroy
    authorize @invoice_item
    @invoice_item.destroy
    redirect_to client_company_path(@invoice_item.client_company)
  end

  # Marks an InvoiceItem as send
  def marked_as_send
    authorize @invoice_item
    @invoice_item.update(sending_date: params[:edit_sending][:sending_date], status: 'Send')
    # UpdateAirtableJob.perform_async(@invoice_item.training, false, @invoice_item)
    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  # Marks an InvoiceItem as paid
  def marked_as_paid
    authorize @invoice_item
    @invoice_item.update(payment_date: params[:edit_payment][:payment_date], status: 'Paid')
    # UpdateAirtableJob.perform_async(@invoice_item.training, false, @invoice_item)
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
    # UpdateAirtableJob.perform_async(@invoice_item.training)
    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  private

  # Filter for index method
  def index_filtered(n = 1)
    if params[:training_id].present?
      @invoice_items_total = InvoiceItem.where(training_id: params[:training_id].to_i, type: params[:type]).order('id DESC')
      @invoice_items = @invoice_items_total.offset((n-1)*50).first(50)
    elsif params[:client_company_id].present?
      @invoice_items_total = InvoiceItem.where(client_company_id: params[:client_company_id].to_i, type: params[:type]).order('id DESC')
      @invoice_items = @invoice_items_total.offset((n-1)*50).first(50)
    elsif params[:client_company_id].nil?
      @invoice_items_total = InvoiceItem.where(type: params[:type]).order('id DESC')
      @invoice_items = @invoice_items_total.offset((n-1)*50).first(50)
    end
  end

  def set_invoice_item
    @invoice_item = InvoiceItem.find(params[:id])
  end

  def invoiceitem_params
    params.require(:invoice_item).permit(:status, :uuid, :object)
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

