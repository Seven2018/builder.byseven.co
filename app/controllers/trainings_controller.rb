class TrainingsController < ApplicationController
  before_action :set_training, only: [:show, :edit, :update, :destroy, :copy, :invoice_form, :trainer_notification_email, :import_attendees]

  def index
    # Index for trainings / Homepage (trainings/index)
    trainings = policy_scope(Training)
    trainings = trainings
    # If user in team SEVEN
    if ['super admin', 'admin', 'project manager'].include?(current_user.access_level)
      # Search trainings
      if params[:search].present?
        # Search trainings involving selected user
        if params[:search][:user].present?
          @user = User.find(params[:search][:user])
          trainings = ((Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(training_ownerships: {user_id: params[:search][:user]}).or(Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:search][:user]})).where("unaccent(lower(trainings.title)) LIKE ?", "%#{I18n.transliterate(params[:search][:title].downcase)}%")) + (Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(training_ownerships: {user_id: params[:search][:user]}).or(Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:search][:user]})).joins(client_contact: :client_company).where("lower(client_companies.name) LIKE ?", "%#{params[:search][:title].downcase}%"))).flatten(1).uniq
          trainings = Training.where(id: trainings)
        else
          trainings = Training.search_by_title_and_company("#{params[:search][:title]}")
        end
      # All trainings involving selected user
      elsif params[:user].present?
        @user = User.find(params[:user])
        trainings = (Training.joins(:training_ownerships).where(training_ownerships: {user_id: params[:user]}).pluck(:id) + Training.joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]}).pluck(:id)).uniq
        # trainings = Training.search_by_title_and_company("#{@user.fullname}")
        trainings = Training.where(id: trainings)
      end
    # If user is Sevener
    else
      # Search trainings involving current user (Sevener)
      if params[:search]
        # WIP
        # trainings = Training.search_by_title_and_company("#{params[:search][:title]} #{current_user.fullname}") if params[:search].present?
      # Trainings index involving current user (Sevener)
      else
        trainings = Training.joins(sessions: :users).where(users: {id: current_user.id}).uniq.select{|x| (x.end_time.present? && x.end_time >= Date.today && x.trainer_last_session(current_user) >= Date.today)}
        trainings = Training.where(id: trainings.map{|x| x.id})
      end
    end
    @upcoming_trainings = trainings_ordered(trainings, 'upcoming')
    all_ids = trainings_ordered(trainings, 'all').map{|x| x.id}
    @trainings = trainings.where(id: all_ids).order_as_specified(id: all_ids)
    respond_to do |format|
      format.html {}
      format.js
    end
  end

  def index_completed
    # If user in team SEVEN
    if ['super admin', 'admin', 'project manager'].include?(current_user.access_level)
      # Search trainings
      if params[:search].present?
        # Search trainings involving selected user
        if params[:search][:user].present?
          @user = User.find(params[:user])
          trainings = ((Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(training_ownerships: {user_id: params[:user]}).or(Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]})).where("unaccent(lower(trainings.title)) LIKE ?", "%#{I18n.transliterate(params[:search][:title].downcase)}%")) + (Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(training_ownerships: {user_id: params[:user]}).or(Training.joins(:training_ownerships).joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]})).joins(client_contact: :client_company).where("lower(client_companies.name) LIKE ?", "%#{params[:search][:title].downcase}%"))).flatten(1).uniq
          trainings = Training.where(id: trainings)
        else
          trainings = Training.search_by_title_and_company("#{params[:search][:title]}")
        end
      elsif params[:user].present?
        @user = User.find(params[:user])
        trainings = (Training.joins(:training_ownerships).where(training_ownerships: {user_id: params[:user]}) + Training.joins(sessions: :session_trainers).where(session_trainers: {user_id: params[:user]})).uniq
        trainings = Training.where(id: trainings)
      else
        trainings = Training.all
      end
      @trainings = trainings_ordered(trainings, 'completed')
    # Index for Sevener Users, with limited visibility
    else
      if params[:search].present?
        # WIP
      else
        @trainings = Training.joins(sessions: :users).where(users: {id: current_user.id}).where_not_exists(:sessions, 'date >= ?', Date.today).distinct.sort_by{|y| y.trainer_last_session(current_user) || Date.new(1970)}.reverse
      end
    end
    skip_authorization
    render partial: "trainings/partials/index_completed"
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

  def show
    authorize @training
    @airtable_training = OverviewTraining.all(filter: "{Builder_id} = '#{@training.id}'").first
    @session = Session.new
    @sessions = Session.where(id: params[:training][:sessions].reject{|x| x.empty?}) if params[:format] == 'pdf'
    if params[:task] == 'update_airtable'
      # UpdateAirtableJob.perform_async(@training, true)
      #@training.trainers.each{|y| @training.export_numbers_sevener(y)}
      #@training.export_airtable
      #@training.export_numbers_activity
    else
      respond_to do |format|
      format.html
      format.pdf do
        render(
          pdf: "#{@training.client_company.name} - #{@training.title}",
          layout: 'pdf.html.erb',
          template: 'trainings/show',
          show_as_html: params.key?('debug'),
          page_size: 'A4',
          encoding: 'utf8',
          dpi: 300,
          zoom: 1,
        )
      end
    end
    end
  end

  def show_session_content
    skip_authorization
    @session = Session.find(params[:session_id])
    render partial: "show_session_content"
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
    redirect_to trainings_path
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
        TrainerNotificationMailer.with(user: user).new_trainer_notification(@training, user).deliver
      end
    elsif params[:trainers][:status] == 'edit'
      user_ids = params[:session][:user_ids][1..-1].map{|x| x.to_i}
      @training.trainers.select{|x| user_ids.include?(x.id)}.each do |user|
        TrainerNotificationMailer.with(user: user).edit_trainer_notification(@training, user).deliver
      end
    end
    redirect_back(fallback_location: root_path)
  end

  def trainer_reminder_email(session, user)
    skip_authorization
    TrainerNotificationMailer.with(user: user).trainer_session_reminder(session, user).deliver
  end

  def redirect_docusign
    skip_authorization
    redirect_to "https://account-d.docusign.com/oauth/auth?response_type=token&scope=signature&client_id=ce366c33-e8f1-4aa7-a8eb-a83fbffee4ca&redirect_uri=http://localhost:3000/docusign/callback"
  end

  def import_attendees
    authorize @training
    AirtableAttendee.all.each do |attendee|
      new_attendee = Attendee.find_by(email: attendee['Email'])
      attendee['Company_id'].present? ? company_id = attendee['Company_id'] : company_id = @training.client_company.id
      new_attendee = Attendee.create(firstname: attendee['Firstname'], lastname: attendee['Lastname'], email: attendee['Email'], client_company_id: company_id) if new_attendee.nil?
      @training.sessions.each do |session|
        SessionAttendee.create(attendee_id: new_attendee.id, session_id: session.id)
      end
    end
    redirect_to training_path(@training)
    flash[:notice] = 'Import successful'
  end

  private

  def set_training
    @training = Training.find(params[:id])
  end

  def training_params
    params.require(:training).permit(:title, :client_contact_id, :mode, :satisfaction_survey, :unit_price, :vat)
  end

  def trainings_ordered(trainings, mode)
    if mode == 'upcoming'
      trainings.where_exists(:sessions, 'date >= ?', Date.today).sort_by{|y| y.next_session}
    elsif mode == 'completed'
      trainings.where_exists(:sessions).where_not_exists(:sessions, 'date >= ?', Date.today).sort_by{|y| y.next_session}
    elsif mode == 'all'
      # trainings.reject{|x| x.end_time.present?} + trainings.reject{|y| !y.end_time.present?}.sort_by{|z| z.end_time}.reverse
      trainings.sort_by{|x| x.end_time || Date.new(1970)}
    end
  end
end
