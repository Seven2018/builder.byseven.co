class TrainingsController < ApplicationController
  before_action :set_training, only: [:show, :edit, :update, :destroy, :copy, :sevener_billing, :invoice_form, :trainer_notification_email]

  def index
    # Index with 'search' option and global visibility for SEVEN Users
    n = params[:page].to_i
    @trainings = policy_scope(Training)
    if ['super admin', 'admin', 'project manager'].include?(current_user.access_level)
      if params[:search]
        if params[:search][:user]
          trainings = ((Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(training_ownerships: {user_id: params[:search][:user]}).or(Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:search][:user]})).where("lower(trainings.title) LIKE ?", "%#{params[:search][:title].downcase}%")) + (Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(training_ownerships: {user_id: params[:search][:user]}).or(Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:search][:user]})).joins(client_contact: :client_company).where("lower(client_companies.name) LIKE ?", "%#{params[:search][:title].downcase}%"))).flatten(1).uniq
          trainings_empty = trainings.reject{|x| x.end_time.present?}
          trainings_with_date = trainings.reject{|y| !y.end_time.present?}.sort_by{|z| z.end_time}.reverse
          @trainings = trainings_empty + trainings_with_date
          @user = User.find(params[:search][:user])
        else
          trainings = ((Training.where("lower(title) LIKE ?", "%#{params[:search][:title].downcase}%")) + (Training.joins(client_contact: :client_company).where("lower(client_companies.name) LIKE ?", "%#{params[:search][:title].downcase}%"))).flatten(1).uniq
          trainings_empty = trainings.reject{|x| x.end_time.present?}
          trainings_with_date = trainings.reject{|y| !y.end_time.present?}.sort_by{|z| z.end_time}.reverse
          @trainings = trainings_empty + trainings_with_date
        end
      elsif params[:user]
        trainings = (Training.joins(:training_ownerships).where(training_ownerships: {user_id: params[:user]}) + Training.joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]})).uniq
        trainings_empty = trainings.reject{|x| x.end_time.present?}
        trainings_with_date = trainings.reject{|y| !y.end_time.present?}.sort_by{|z| z.end_time}.reverse
        @trainings = trainings_empty + trainings_with_date
        @user = User.find(params[:user])
      end
    end
  end

  def index_upcoming
    # Index with 'search' option and global visibility for SEVEN Users
    if ['super admin', 'admin', 'project manager'].include?(current_user.access_level)
      if params[:user].present?
        @trainings = (Training.joins(:training_ownerships).where(training_ownerships: {user_id: params[:user]}) + Training.joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]})).uniq
        @trainings = @trainings.select{|x| x.end_time.present? && x.end_time >= Date.today}.sort_by{|y| y.next_session}
        @user = User.find(params[:user])
      else
        @trainings = Training.all.select{|x| x.end_time.present? && x.end_time >= Date.today}.sort_by{|y| y.next_session}
      end
    # Index for Sevener Users, with limited visibility
    else
      # @trainings = Training.joins(sessions: :users).where("users.email LIKE ?", "#{current_user.email}").uniq.select{|x| x.end_time.present? && x.end_time >= Date.today}.sort_by{|y| y.next_session}
      # @trainings = (Training.joins(sessions: :users).where(users: {id: current_user.id}).uniq.select{|x| Session.joins(:session_trainers).where(training_id: x.id, session_trainers: {user_id: current_user.id}).order(date: :asc).reject{|c| !c.date.present?}.last.date >= Date.today}.sort_by{|y| y.next_session} + Training.joins(sessions: :users).where(sessions: {date: nil}, users: {id: current_user.id}).uniq).uniq
      @trainings = (Training.joins(sessions: :users).where(users: {id: current_user.id}).uniq.select{|x| if (sessions = Session.joins(:session_trainers).where(training_id: x.id, session_trainers: {user_id: current_user.id}).order(date: :asc).reject{|c| !c.date.present?}).present?; sessions.last.date >= Date.today; end;}.sort_by{|y| y.next_session} + Training.joins(sessions: :users).where(sessions: {date: nil}, users: {id: current_user.id}).uniq).uniq
      @trainings_count = @trainings.count
    end
    skip_authorization
    render partial: "index_upcoming"
  end

  def index_completed
    if ['super admin', 'admin', 'project manager'].include?(current_user.access_level)
      if params[:user].present?
        @trainings = (Training.joins(:training_ownerships).where(training_ownerships: {user_id: params[:user]}) + Training.joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]})).uniq
        @trainings = @trainings.select{|x| x.end_time.present? && x.end_time < Date.today}.sort_by{|y| y.end_time}.reverse
        @user = User.find(params[:user])
      else
        # trainings = (Training.all.select{|x| x.next_session.present?}.sort_by{|y| y.next_session} + Training.all.select{|z| !z.next_session.present? && z.end_time.present?}.sort_by{|a| a.end_time}.reverse)
        @trainings = Training.all.select{|x| x.end_time.present? && x.end_time < Date.today}.sort_by{|y| y.end_time}.reverse
      end
    # Index for Sevener Users, with limited visibility
    else
      # @trainings = Training.joins(sessions: :users).where(users: {id: current_user.id}).uniq.select{|x| Session.joins(:session_trainers).where(training_id: x.id, session_trainers: {user_id: current_user.id}).order(date: :asc).last.date < Date.today}.sort_by{|y| y.end_time}.reverse
      @trainings = (Training.joins(sessions: :users).where(users: {id: current_user.id}).uniq.select{|x| Session.joins(:session_trainers).where(training_id: x.id, session_trainers: {user_id: current_user.id}).order(date: :asc).reject{|c| !c.date.present?}.last.date < Date.today}.sort_by{|y| y.end_time}.reverse - Training.joins(sessions: :users).where(sessions: {date: nil}, users: {id: current_user.id}).uniq).uniq

    end
    skip_authorization
    render partial: "index_completed"
  end

  # Index with weekly calendar view
  def index_week
    @trainings = Training.all
    @sessions = Session.all
    authorize @trainings
  end

  # Index with monthly calendar view
  def index_month
    @trainings = Training.all
    @sessions = Session.all
    authorize @trainings
  end

  def show
    authorize @training
    @training_ownership = TrainingOwnership.new
    @session = Session.new
    unless params[:page].present?
      redirect_to training_path(@training, page: 1)
    end
    if params[:task] == 'update_airtable'
      UpdateAirtableJob.perform_async(@training, true)
      #@training.trainers.each{|y| @training.export_numbers_sevener(y)}
      #@training.export_airtable
      #@training.export_numbers_activity
    end
  end

  def show_session_content
    skip_authorization
    @session = Session.find(params[:session_id])
    render partial: "show_session_content"
  end

  def new
    @training = Training.new
    @training_ownership = TrainingOwnership.new
    @clients = ClientContact.all
    authorize @training
  end

  def create
    @training = Training.new(training_params)
    authorize @training
    begin
      @training.refid = "#{Time.current.strftime('%y')}-#{(Training.last.refid[-4..-1].to_i + 1).to_s.rjust(4, '0')}"
    rescue
    end
    @training.satisfaction_survey = 'https://learn.byseven.co/survey'
    if @training.save
      redirect_to training_path(@training)
    else
      render :new
    end
  end

  def edit
    authorize @training
    @training.export_airtable
  end

  def update
    authorize @training
    @training.update(training_params)
    @training.save
    # UpdateAirtableJob.perform_async (@training)
    # @training.export_airtable
    redirect_to training_path(@training)
  end

  def destroy
    authorize @training
    @training.destroy
    redirect_to trainings_path(page: 1)
  end

  def copy
    authorize @training
    target_training = Training.find(params[:copy][:training_id])
    if target_training.present?
      @training.sessions.each do |session|
        new_session = Session.create(session.attributes.except("id", "created_at", "updated_at", "training_id", "address", "room"))
        new_session.update(training_id: target_training.id)
        session.workshops.each do |workshop|
          new_workshop = Workshop.create(workshop.attributes.except("id", "created_at", "updated_at", "session_id"))
          new_workshop.update(session_id: new_session.id)
          workshop.workshop_modules.each do |mod|
            new_mod = WorkshopModule.create(mod.attributes.except("id", "created_at", "updated_at", "workshop_id", "user_id"))
            new_mod.update(workshop_id: new_workshop.id)
          end
          j = 1
          new_workshop.workshop_modules.order(position: :asc).each{|mod| mod.update(position: j); j += 1}
        end
        i = 1
        new_session.workshops.order(position: :asc).each{|workshop| workshop.update(position: i); i += 1}
      end
      redirect_to training_path(target_training)
    else
      raise
    end
  end

  def invoice_form
    authorize @training
    @user = OverviewUser.all.select{|x| x['Builder_id'] == current_user.id}&.first
    @airtable_training = OverviewTraining.all.select{|x| x['Builder_id'] == @training.id}&.first
    invoices = OverviewInvoiceSevener.all.select{|x| x['User_id'] == [current_user.id] && x['Training_id'] == [@training.id]}
    intervention = OverviewNumbersSevener.all.select{|x| x['Training_id'] == @training.id && x['User_id'] == current_user.id}.first
    amount_due = intervention['Total Due (excl. VAT)'].to_f - intervention['Total Paid'].to_f
    amount_billed = invoices.map{|x| x['Amount']}.sum if invoices.present?
    invoices.present? ? @amount_to_bill = amount_due - amount_billed : @amount_to_bill = amount_due
  end

  def certificate
    skip_authorization
    @attendee = params[:attendee][:name]
    set_training
    respond_to do |format|
      format.pdf do
        render(
          pdf: "#{@training.title} - Certificat de réalisation - #{@attendee}",
          layout: 'pdf.html.erb',
          template: 'pdfs/certificate',
          margin: { bottom: 30 },
          footer: { margin: { top: 0, bottom: 0 }, html: { template: 'pdfs/certificate_footer.pdf.erb' } },
          show_as_html: params.key?('debug'),
          page_size: 'A4',
          encoding: 'utf8',
          dpi: 300,
          zoom: 1,
        )
      end
    end
  end

  def certificate_rs
    skip_authorization
    @attendee = params[:attendee][:name]
    set_training
    respond_to do |format|
      format.pdf do
        render(
          pdf: "#{@training.title} - Certificat de réalisation - #{@attendee}",
          layout: 'pdf.html.erb',
          template: 'pdfs/certificate_rs',
          margin: { bottom: 30 },
          footer: { margin: { top: 0, bottom: 0 }, html: { template: 'pdfs/certificate_rs_footer.pdf.erb' } },
          show_as_html: params.key?('debug'),
          page_size: 'A4',
          encoding: 'utf8',
          dpi: 300,
          zoom: 1,
        )
      end
    end
  end

  def trainer_notification_email
    authorize @training
    if params[:status] == 'new'
      @training.trainers.each do |user|
      # if ['sevener+','sevener'].include?(user.access_level)
          TrainerNotificationMailer.with(user: user).new_trainer_notification(@training, user).deliver
      # end
      end
    elsif params[:trainers][:status] == 'edit'
      user_ids = params[:session][:user_ids][1..-1].map{|x| x.to_i}
      @training.trainers.select{|x| user_ids.include?(x.id)}.each do |user|
        # if ['sevener+','sevener'].include?(user.access_level)
            TrainerNotificationMailer.with(user: user).edit_trainer_notification(@training, user).deliver
        # end
      end
    end
    redirect_back(fallback_location: root_path)
  end

  def trainer_reminder_email(session, user)
    skip_authorization
    # if ['sevener+','sevener'].include?(user.access_level)
      TrainerNotificationMailer.with(user: user).trainer_session_reminder(session, user).deliver
    # end
  end

  def redirect_docusign
    skip_authorization
    redirect_to "https://account-d.docusign.com/oauth/auth?response_type=token&scope=signature&client_id=ce366c33-e8f1-4aa7-a8eb-a83fbffee4ca&redirect_uri=http://localhost:3000/docusign/callback"
  end

  private

  def set_training
    @training = Training.find(params[:id])
  end

  def training_params
    params.require(:training).permit(:title, :client_contact_id, :mode, :satisfaction_survey, :unit_price, :vat)
  end
end
