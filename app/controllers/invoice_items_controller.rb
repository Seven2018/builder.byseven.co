class InvoiceItemsController < ApplicationController
  before_action :set_invoice_item, only: [:show, :edit, :marked_as_paid, :upload_to_sheet, :destroy]

  def index
    @invoice_items = policy_scope(InvoiceItem)
    index_filtered
  end

  def report
    @invoice_items = InvoiceItem.all
    @invoice_items_grid = InvoiceItemsGrid.new(params[:invoice_items_grid])
    authorize @invoice_items
  end

  def show
    authorize @invoice_item
    respond_to do |format|
      format.html
      format.pdf do
        render(
          pdf: "#{@invoice_item.uuid}",
          layout: 'pdf.html.erb',
          :margin => { :bottom => 55, :top => 52 },
          :header => { :margin => { :top => 0, :bottom => 0 }, :html => { :template => 'invoice_items/header.pdf.erb' } },
          :footer => { :margin => { :top => 0, :bottom => 0 }, :html => { :template => 'invoice_items/footer.pdf.erb' } },
          template: 'invoice_items/show',
          background: true,
          show_as_html: params.key?('debug'),
          page_size: 'A4',
          encoding: 'utf8',
          dpi: 300,
          zoom: 1,
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
      redirect_to invoice_item_path(@invoice_item)
    end
  end

  def marked_as_paid
    authorize @invoice_item
    index_filtered
    @invoice_item.type == 'Invoice' ? @invoice_item.update(status: 'Payée') : @invoice_item.update(status: 'Accepté')
    respond_to do |format|
      format.html {redirect_to invoice_items_path(type: @invoice_item.type)}
      format.js
    end
  end

  def new_invoice_item
    @training = Training.find(params[:training_id])
    @client_company = ClientCompany.find(params[:client_company_id])
    @invoice = InvoiceItem.new(training_id: params[:training_id].to_i, client_company_id: params[:client_company_id].to_i, type: params[:type])
    authorize @invoice
    @invoice.type == 'Invoice' ? @invoice.uuid = "FA#{Date.today.strftime('%Y')}%05d" % (Invoice.count+1) : @invoice.uuid = "DE#{Date.today.strftime('%Y')}%05d" % (Estimate.count+1)
    @invoice.type == 'Invoice' ? @invoice.status = 'Non payée' : @invoice.status = 'En attente'
    if @training.client_contact.client_company.client_company_type == 'Entreprise'
      product = Product.find(2)
      quantity = 0
      @training.sessions.each do |session|
        session.duration < 4 ? quantity += 0.5 * session.session_trainers.count : quantity += 1 * session.session_trainers.count
      end
      InvoiceLine.create(invoice_item: @invoice, description: product.name, quantity: quantity, net_amount: product.price, tax_amount: product.tax)
    else
      product = Product.find(1)
      quantity = 0
      @training.sessions.each do |session|
      quantity += session.duration
      end
      InvoiceLine.create(invoice_item: @invoice, description: product.name, quantity: quantity, net_amount: product.price, tax_amount: product.tax)
    end
    update_price(@invoice)
    if @invoice.save
      redirect_to invoice_item_path(@invoice)
    end
  end

  def new_sevener_invoice
    @training = Training.find(params[:training_id])
    @client_company = ClientCompany.find(params[:client_company_id])
    @sevener_invoice = InvoiceItem.new(training_id: params[:training_id].to_i, client_company_id: params[:client_company_id].to_i, issue_date: Date.today, due_date: Date.today + 1.months, user_id: current_user.id, type: 'InvoiceSevener')
    authorize @sevener_invoice
    @sevener_invoice.uuid = "#{current_user.firstname[0]}#{current_user.lastname[0]}#{Date.today.strftime('%Y')}%05d" % (InvoiceSevener.where(user_id: current_user.id).count+1)
    if @training.client_contact.client_company.client_company_type == 'Entreprise'
      product = Product.find(10)
      quantity = 0
      @training.sessions.each do |session|
        session.duration < 4 ? quantity += 0.5 : quantity += 1
      end
      InvoiceLine.create(invoice_item: @sevener_invoice, description: product.name, quantity: quantity, net_amount: product.price, tax_amount: product.tax)
    else
      product = Product.find(11)
      quantity = 0
      @training.sessions.each do |session|
        quantity += session.duration
      end
      InvoiceLine.create(invoice_item: @sevener_invoice, description: product.name, quantity: quantity, net_amount: product.price, tax_amount: product.tax)
    end
    update_price(@sevener_invoice)
    redirect_to invoice_item_path(@sevener_invoice) if @sevener_invoice.save
  end

  def upload_to_sheet
    authorize @invoice_item
    @training = @invoice_item.training
    session = GoogleDrive::Session.from_service_account_key("client_secret.json")
    spreadsheet = session.spreadsheet_by_title("Copie de Seven Numbers #{@invoice_item.issue_date.strftime('%Y')}")
    worksheet = spreadsheet.worksheets.first
    preparation = 0
    costs = 0
    deposit = 0
    @invoice_item.invoice_lines.each do |line|
      if line.product.product_type == 'Préparation'
        preparation += line.quantity * line.net_amount
      elsif
        line.product.product_type == 'Frais'
        costs += line.quantity * line.net_amount
      elsif
        line.product.product_type == 'Caution'
        deposit += line.quantity * line.net_amount
      end
    end
    @invoice_item.training.client_contact.client_company.client_company_type == 'Entreprise' ? unit = 'j' : unit = 'h'
    worksheet.delete_rows((Invoice.count+1), 1)
    worksheet.insert_rows((Invoice.count+1), [[@training.start_date.strftime('%d/%m/%y'), @training.end_date.strftime('%d/%m/%y'), @training.client_contact.client_company.name, @training.title, invoice_item_url(@invoice_item), @invoice_item.invoice_lines.first.quantity, unit, @invoice_item.invoice_lines.first.net_amount.round, (@invoice_item.invoice_lines.first.net_amount*@invoice_item.invoice_lines.first.quantity).round, preparation, deposit, @invoice_item.tax_amount.round, costs, '', (@invoice_item.total_amount - @invoice_item.tax_amount).round, @invoice_item.uuid, @invoice_item.issue_date.strftime('%d/%m/%y')]])
    worksheet.save
    redirect_to invoice_item_path(@invoice_item)
    flash[:notice] = "Uploadé avec succès"
  end

  private

  def index_filtered
    if params[:training_id]
      @invoice_items = InvoiceItem.where(training_id: params[:training_id].to_i)
    elsif params[:client_company_id].nil?
      @invoice_items = InvoiceItem.all.order('id DESC')
    elsif params[:type] == 'Invoice'
      @invoice_items = Invoice.where(client_company_id: params[:client_company_id].to_i).order('id DESC')
    elsif params[:type] == 'Estimate'
      @invoice_items = Estimate.where(client_company_id: params[:client_company_id].to_i).order('id DESC')
    end
    return @invoice_items
  end

  def update_price(invoice)
    total = 0
    tax = 0
    invoice.invoice_lines.each do |line|
      total += line.quantity * line.net_amount * (1 + line.tax_amount/100)
      tax += line.quantity * line.net_amount * (line.tax_amount/100)
    end
    invoice.update(total_amount: total, tax_amount: tax)
    invoice.save
  end

  def set_invoice_item
    @invoice_item = InvoiceItem.find(params[:id])
  end

  def invoiceitem_params
    params.require(:invoice_item).permit(:status, :uuid)
  end
end
