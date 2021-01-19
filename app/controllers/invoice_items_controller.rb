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
  before_action :set_invoice_item, only: [:show, :edit, :copy, :copy_here, :transform_to_invoice, :edit_client, :credit, :marked_as_send, :marked_as_paid, :marked_as_reminded, :destroy, :upload_sevener_invoice_to_drive]

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
      @invoice_item.export_numbers_revenue
      redirect_to invoice_item_path(@invoice_item)
    end
  end

  # Creates a chart (Numbers) of InvoicesItems, for reporting purposes (gem)
  def report
    # params[:date].present? ? @invoice_items = InvoiceItem.where(type: 'Invoice').where("created_at > ? AND created_at < ?", params[:date][:start_date], params[:date][:end_date]) : @invoice_items = InvoiceItem.where(type: 'Invoice').where("created_at > ? AND created_at < ?", Date.today.beginning_of_year, Date.today)
    # authorize @invoice_items
    # params[:date].present? ? @sessions = Session.where("date > ? AND created_at < ?", params[:date][:start_date], params[:date][:end_date]) : @sessions = Session.where("date > ? AND created_at < ?", Date.today.beginning_of_year, Date.today)
    # respond_to do |format|
    #   format.html
    #   format.csv { send_data @invoice_items_grid.to_csv }
    # end
    @invoice_items = InvoiceItem.all
    authorize @invoice_items
    # if params[:date].present?
    #   OverviewUser.all.select{|x| x['Status'] == 'SEVEN'}.each do |user|
    #     ownership_hours_total = Training.joins(:training_ownerships).where(training_ownerships: {user_type: 'Owner', user_id: user['Builder_id'].to_i}).select{|x| x.end_time.present? && x.end_time >= Date.today.beginning_of_year && x.end_time <= Date.today.end_of_year}.map{|x| x.hours}.sum
    #     ownership_hours_ongoing = Training.joins(:training_ownerships).where(training_ownerships: {user_type: 'Owner', user_id: user['Builder_id'].to_i}).select{|x| x.end_time.present? && x.end_time >= Date::strptime(params[:date][:start_date],'%Y-%m-%d') && x.end_time <= Date::strptime(params[:date][:end_date],'%Y-%m-%d')}.map{|x| x.hours}.sum
    #     projects_1 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '1 - Prospect(s) : person or/and company'}.count
    #     projects_2 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '2 - Identified contact lead'}.count
    #     projects_3 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '3 - Handshaked contact lead'}.count
    #     projects_4 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '4 - Strong relationship lead'}.count
    #     projects_5 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '5 - Needs identified lead'}.count
    #     projects_6 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '6 - Pre-Signed lead'}.count
    #     projects_7 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '7 - Signed lead'}.count
    #     memos_this_week = OverviewMemo.all.select{|x| x['User'].present? && x['User'].join == user.id && Date::strptime(x['Date'], "%Y-%m-%d") >= Date.today.weeks_ago(1)}.count
    #     new_record = OverviewBizdev.create('User' => user['Name'], 'Ownership (hours) 2021' => ownership_hours_total, 'Ownership (hours) 2021 ongoing' => ownership_hours_ongoing, 'Projects - Lead Level 1' => projects_1, 'Projects - Lead Level 2' => projects_2, 'Projects - Lead Level 3' => projects_3,'Projects - Lead Level 4' => projects_4,'Projects - Lead Level 5' => projects_5,'Projects - Lead Level 6' => projects_6,'Projects - Lead Level 7' => projects_7, 'Memos (last week)' => memos_this_week)
    #     new_record.save
    #   end
    # end
    if params[:date].present?
      week = "Week #{Date.today.weeks_ago(1).strftime("%U").to_i}"
      OverviewUser.all.select{|x| x['Status'] == 'SEVEN'}.each do |user|
        # ownership_hours_total = Training.joins(:training_ownerships).where(training_ownerships: {user_type: 'Owner', user_id: user['Builder_id'].to_i}).select{|x| x.end_time.present? && x.end_time >= Date.today.beginning_of_year && x.end_time <= Date.today.end_of_year}.map{|x| x.hours}.sum.to_s
        # ownership_hours_ongoing = Training.joins(:training_ownerships).where(training_ownerships: {user_type: 'Owner', user_id: user['Builder_id'].to_i}).select{|x| x.end_time.present? && x.end_time >= Date::strptime(params[:date][:start_date],'%Y-%m-%d') && x.end_time <= Date::strptime(params[:date][:end_date],'%Y-%m-%d')}.map{|x| x.hours}.sum.to_s
        # ownership_hours_ongoing = OverviewTraining.all.select{|x| x['Owner'].present? && x['Owner'].join == user.id}.select{|x| x['Due Date'].present? && Date::strptime(x['Due Date'],'%Y-%m-%d') >= Date::strptime(params[:date][:start_date],'%Y-%m-%d') && Date::strptime(x['Due Date'],'%Y-%m-%d') <= Date::strptime(params[:date][:end_date],'%Y-%m-%d')}.map{|x| if x['Hours'].present?; x['Hours']; end}.sum.to_s
        ownership_hours_ongoing = OverviewTraining.all.select{|x| x['Owner'].present? && x['Owner'].join == user.id}.select{|x| x['Due Date'].present? && Date::strptime(x['Due Date'],'%Y-%m-%d') >= Date.today.weeks_ago(2).beginning_of_week}.map{|x| if x['Hours'].present?; x['Hours']; end}.sum.to_s
        project_hours_dev = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id}.map{|z| z['Hours'].to_i}.sum.to_s
        project_hours_codev = OverviewProject.all.select{|x| x['Co-developer'].present? && x['Co-developer'].join == user.id}.map{|z| z['Hours'].to_i}.sum.to_s
        projects_1 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '1 - Prospect(s) : person or/and company'}.count.to_s
        projects_2 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '2 - Identified contact lead'}.count.to_s
        projects_3 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '3 - Handshaked contact lead'}.count.to_s
        projects_4 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '4 - Strong relationship lead'}.count.to_s
        projects_5 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '5 - Needs identified lead'}.count.to_s
        projects_6 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '6 - Pre-Signed lead'}.count.to_s
        projects_7 = OverviewProject.all.select{|x| x['Developer'].present? && x['Developer'].join == user.id && x['Lead Qualification Level'] == '7 - Signed lead'}.count.to_s
        memos_this_week = OverviewMemo.all.select{|x| x['User'].present? && x['User'].join == user.id && Date::strptime(x['Date'], "%Y-%m-%d") >= Date.today.weeks_ago(1)}.count.to_s
        data_hash = {Ongoing_Ownership:  ownership_hours_ongoing, Project_Hours_Dev: project_hours_dev, Project_Hours_Codev: project_hours_codev, Projects_Level_1: projects_1, Projects_Level_2: projects_2, Projects_Level_3: projects_3, Projects_Level_4: projects_4, Projects_Level_5: projects_5, Projects_Level_6: projects_6, Projects_Level_7: projects_7, Weekly_Memos: memos_this_week}
        data_hash.each do |key, value|
          line = OverviewBizdev.all.select{|x| x['User'] == user['Name'] && x['Data'] == key.to_s}.first
          if !line.present?
            line = OverviewBizdev.create('User' => user['Name'], 'Data' => key, week => value)
          else
            line[week] = value
          end
          line.save
        end
      end
    end
  end

  # Creates a new InvoiceItem, proposing a pre-filled version to be edited if necessary
  def new_invoice_item
    @training = Training.find(params[:training_id])
    @client_company = ClientCompany.find(params[:client_company_id])
    @invoice = InvoiceItem.new(training_id: params[:training_id].to_i, client_company_id: params[:client_company_id].to_i, type: params[:type])
    authorize @invoice
    # attributes a invoice number to the InvoiceItem
    if params[:type] == 'Invoice'
      InvoiceItem.where(type: 'Invoice').count != 0 ? (@invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
    elsif params[:type] == 'Estimate'
      InvoiceItem.where(type: 'Estimate').count != 0 ? (@invoice.uuid = "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "DE#{Date.today.strftime('%Y')}00001")
    end
    @invoice.status = 'En attente'
    # Fills the created InvoiceItem with InvoiceLines, according Training data
    if @training.client_contact.client_company.client_company_type == 'Company'
      product = Product.find(2)
      quantity = 0
      @training.sessions.each do |session|
        session.duration < 4 ? quantity += 0.5 * session.session_trainers.count : quantity += 1 * session.session_trainers.count
      end
      InvoiceLine.create(invoice_item: @invoice, description: @training.title, quantity: quantity, net_amount: product.price, tax_amount: product.tax, product_id: product.id, position: 1)
    else
      product = Product.find(1)
      quantity = 0
      @training.sessions.each do |session|
      quantity += session.duration
      end
      InvoiceLine.create(invoice_item: @invoice, description: @training.title, quantity: quantity, net_amount: product.price, tax_amount: product.tax, product_id: product.id, position: 1)
    end
    @invoice.update_price
    if @invoice.save
      @invoice.export_numbers_revenue if @invoice.type == 'Invoice'
      redirect_to invoice_item_path(@invoice)
    end
  end

  # Creates a new InvoiceItem using data from Airtable DB
  def new_airtable_invoice_item
    @training = Training.find(params[:training_id])
    airtable_training = OverviewTraining.all.select{|x|x['Reference SEVEN'] == @training.refid}.first
    @client_company = ClientCompany.find(params[:client_company_id])
    @invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: params[:type])
    skip_authorization
    # attributes a invoice number to the InvoiceItem
    if params[:type] == 'Invoice'
      InvoiceItem.where(type: 'Invoice').count != 0 ? (@invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
    elsif params[:type] == 'Estimate'
      InvoiceItem.where(type: 'Estimate').count != 0 ? (@invoice.uuid = "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@invoice.uuid = "DE#{Date.today.strftime('%Y')}00001")
    end
    @invoice.status = 'En attente'
    # Fills the created InvoiceItem with InvoiceLines, according Training data
    @training.client_contact.client_company.client_company_type == 'Company' ? product = Product.find(2) : product = Product.find(1)
    line = InvoiceLine.new(invoice_item: @invoice, description: @training.client_company.name + ' - ' + @training.title, quantity: airtable_training['Unit Number'], net_amount: airtable_training['Unit Price'], tax_amount: product.tax, product_id: product.id, position: 1)
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
    if airtable_training['Preparation'].present?
      preparation = Product.find(3)
      InvoiceLine.create(invoice_item: @invoice, description: 'Préparation formation', quantity: 1, net_amount: airtable_training['Preparation'], tax_amount: preparation.tax, product_id: preparation.id, position: 2)
    end
    @invoice.update_price
    if @invoice.save
      @invoice.export_numbers_revenue if @invoice.type = 'Invoice'
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
      InvoiceItem.where(type: 'Invoice').count != 0 ? (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
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
      new_invoice.export_numbers_revenue if new_invoice.type = 'Invoice'
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
      @training.attendees.each do |attendee|
        new_invoice = InvoiceItem.new(training_id: @training.id, client_company_id: @client_company.id, type: 'Invoice')
        InvoiceItem.where(type: 'Invoice').count != 0 ? (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (new_invoice.uuid = "FA#{Date.today.strftime('%Y')}00001")
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
        new_invoice.export_numbers_revenue if new_invoice.type = 'Invoice'
      end
    end
    redirect_to invoice_items_path(type: 'Invoice', training_id: @training.id)
    flash[:alert] = "This training unit type is not defined as 'Participant' in Airtable." unless airtable_training['Unit Type'] == 'Participant'
  end

  def new_estimate
    @client_company = ClientCompany.find(params[:client_company_id])
    @estimate = InvoiceItem.new(client_company_id: params[:client_company_id].to_i, type: 'Estimate')
    authorize @estimate
    Estimate.all.count != 0 ? (@estimate.uuid = "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')) : (@estimate.uuid = "DE#{Date.today.strftime('%Y')}00001")
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

  # Allows the duplication of an InvoiceItem
  def copy
    authorize @invoice_item
    @training = Training.find(params[:copy][:training_id]) if params[:copy][:training_id].present?
    new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "training_id", "client_company_id", "status", "sending_date", "payment_date", "dunning_date"))
    if @invoice_item.type == 'Invoice'
      new_invoice_item.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    else
      new_invoice_item.uuid = "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    end
    new_invoice_item.training_id = @training.id if @training.present?
    new_invoice_item.client_company_id = params[:copy][:client_company_id]
    new_invoice_item.status = 'En attente'
    if new_invoice_item.save
      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: new_invoice_item.id)
      end
      new_invoice.update_price
      new_invoice.export_numbers_revenue if new_invoice.type = 'Invoice'
      redirect_to invoice_item_path(new_invoice_item)
    else
      raise
    end
  end

  # Allows the duplication of an InvoiceItem within the same Training
  def copy_here
    authorize @invoice_item
    new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "sending_date", "payment_date", "dunning_date"))
    if @invoice_item.type == 'Invoice'
      new_invoice_item.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    else
      new_invoice_item.uuid = "DE#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Estimate').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    end
    new_invoice_item.status = 'En attente'
    if new_invoice_item.save
      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: new_invoice_item.id)
      end
      new_invoice_item.update_price
      new_invoice_item.export_numbers_revenue if new_invoice_item.type = 'Invoice'
      redirect_to invoice_item_path(new_invoice_item)
    else
      raise
    end
  end

  def transform_to_invoice
    authorize @invoice_item
    new_invoice_item = InvoiceItem.new(@invoice_item.attributes.except("id", "created_at", "updated_at", "sending_date", "payment_date", "dunning_date"))
    new_invoice_item.uuid = "FA#{Date.today.strftime('%Y')}" + (InvoiceItem.where(type: 'Invoice').last.uuid[-5..-1].to_i + 1).to_s.rjust(5, '0')
    new_invoice_item.status = 'En attente'
    new_invoice_item.type = 'Invoice'
    if new_invoice_item.save
      @invoice_item.invoice_lines.each do |line|
        new_invoice_line = InvoiceLine.create(line.attributes.except("id", "created_at", "updated_at", "invoice_item_id"))
        new_invoice_line.update(invoice_item_id: new_invoice_item.id)
      end
      new_invoice_item.update_price
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
    @invoice_item.export_numbers_revenue
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
      redirect_to invoice_item_path(credit)
    else
      raise
    end
  end

  def send_invoice_mail
    raise
  end

  # Marks an InvoiceItem as send
  def marked_as_send
    authorize @invoice_item
    index_filtered
    @invoice_item.update(sending_date: params[:edit_sending][:sending_date])
    redirect_back(fallback_location: invoice_item_path(@invoice_item))
  end

  # Marks an InvoiceItem as paid
  def marked_as_paid
    authorize @invoice_item
    index_filtered
    @invoice_item.update(payment_date: params[:edit_payment][:payment_date])
    @invoice_item.export_numbers_revenue if @invoice_item.type = 'Invoice'
    redirect_back(fallback_location: invoice_item_path(@invoice_item, page: 1))
  end

  # Marks an InvoiceItem as reminded
  def marked_as_reminded
    authorize @invoice_item
    index_filtered
    @invoice_item.update(dunning_date: params[:edit_payment][:dunning_date])
    redirect_back(fallback_location: invoice_item_path(@invoice_item, page: 1))
  end

  # Destroys an InvoiceItem
  def destroy
    authorize @invoice_item
    @invoice_item.destroy
    redirect_to client_company_path(@invoice_item.client_company)
  end

  # Upload to GDrive
  # def redirect_upload_to_drive
  #   skip_authorization
  #   client = Signet::OAuth2::Client.new(client_options)
  #   # Allows to pass informations through the Google Auth as a complex string
  #   client.update!(state: Base64.encode64(params[:invoice_item_id] + '|' + params[:file].tempfile))
  #   redirect_to client.authorization_uri.to_s
  # end

  # def upload_to_drive
  #   # @invoice_item = InvoiceItem.find(Base64.decode64(params[:state]).split('|').first)
  #   @invoice_item = InvoiceItem.find(params[:invoice_item_id])
  #   # file_path = Base64.decode64(params[:state]).split('|').last
  #   file_path = params[:file].tempfile
  #   authorize @invoice_item
  #   require 'google/apis/drive_v3'

  #   access_token = AccessToken.new 'SECRET_TOKEN'
  #   drive_service = Google::Apis::DriveV3::DriveService.newc
  #   # client = Signet::OAuth2::Client.new(client_options)
  #   client = Signet::OAuth2::Client.new(client_options)
  #   drive_service.authorization = access_token

  #   # metadata = Drive::File.new(title: 'My document')
  #   # metadata = drive.insert_file(metadata, upload_source: 'test.txt', content_type: 'text/plain')
  #   file_metadata = {
  #     name: 'my_file_name.pdf',
  #     # parents: [folder_id],
  #     description: 'This is my file'
  #   }
  #   file = drive_service.create_file(file_metadata, upload_source: file_path, fields: 'id')
  # end

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

  def client_options
    {
      client_id: Rails.application.credentials.google_client_id,
      client_secret: Rails.application.credentials.google_client_secret,
      authorization_uri: 'https://accounts.google.com/o/oauth2/auth',
      token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
      scope: Google::Apis::DriveV3::AUTH_DRIVE,
      redirect_uri: "#{request.base_url}/upload_to_drive"
    }
  end

  def set_invoice_item
    @invoice_item = InvoiceItem.find(params[:id])
  end

  def invoiceitem_params
    params.require(:invoice_item).permit(:status, :uuid)
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

