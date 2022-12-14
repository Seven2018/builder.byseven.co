class TrainingsController < ApplicationController
  before_action :set_training, only: [:show, :edit, :update, :destroy, :copy, :invoice_form, :trainer_notification_email, :import_attendees, :export_training_to_airtable]

  ##########
  ## CRUD ##
  ##########

  def index
    # Index for trainings / Homepage (trainings/index)
    trainings = search_trainings

    @upcoming_trainings = trainings_ordered(trainings, 'upcoming')
    @upcoming_any_more = @upcoming_trainings.count - 10
    @upcoming_trainings = @upcoming_trainings.first(10)

    @completed_trainings = trainings_ordered(trainings, 'completed')

    all_ids = trainings_ordered(trainings, 'all').map(&:id)
    trainings = trainings.where(id: all_ids).order_as_specified(id: all_ids)

    @trainings_to_date = trainings.where(training_type: ['Training', nil])
    @trainings_to_date = @trainings_to_date.where_exists(:sessions, date: nil).or(@trainings_to_date.where_not_exists(:sessions))
    @to_date_any_more = @trainings_to_date.count - 10
    @trainings_to_date = @trainings_to_date.first(10)

    trainings_to_staff_ids = Session.where(training_id: trainings.ids).where('date >= ?', Date.today).where_not_exists(:session_trainers).map(&:training_id).uniq
    @trainings_to_staff = Training.where(id: trainings_to_staff_ids)

    @trainings_home = Training.where(training_type: 'Home').order(title: :asc)

    respond_to do |format|
      format.html {}
      format.js
    end
  end

  def index_completed
    skip_authorization
    trainings = search_trainings

    @trainings = trainings_ordered(trainings, 'completed')
    render partial: "trainings/index/index_completed", locals: {completed_trainings: @trainings}
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

    begin
      @airtable_training = OverviewTraining.find(@training.airtable_id) if @training.airtable_id.present?
    rescue
    end

    @session = Session.new
    @sessions = Session.where(id: params[:training][:sessions].reject{|x| x.empty?}) if params[:format] == 'pdf'

    if params[:task] == 'update_airtable'
      UpdateAirtableJob.perform_async(@training, true)
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
  end

  def update
    authorize @training

    @training.update(training_params)
    @training.save

    UpdateAirtableJob.perform_async(@training)

    redirect_to training_path(@training)
  end

  def destroy
    authorize @training
    @training.destroy
    redirect_to trainings_path
  end


  ##################
  ## EMAIL SYSTEM ##
  ##################

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


  ###############
  ## ATTENDEES ##
  ###############

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


  #########################
  ## SEARCH AUTOCOMPLETE ##
  #########################

  def trainings_search
    skip_authorization

    if params[:search] == ""
      @trainings = Training.all.includes(:client_company).order('client_companies.name asc', title: :asc)
    else
      @trainings = Training.all.ransack(title_or_client_company_name_cont: params[:search])
      @trainings.sorts = ['client_company.name asc', 'title asc']
      @trainings = @trainings.result(distinct: true)
    end

    @trainings = @trainings.limit(50).map{|x| [x.id, (x.client_company.name + ' - ' + x.title + ' - id: ' + x.id.to_s)]}

    render partial: 'shared/tools/select_autocomplete', locals: { elements: @trainings }
  end


  ##############
  ## AIRTABLE ##
  ##############

  def airtable_create_training
    airtable_training = OverviewTraining.find(params[:record_id])
    skip_authorization

    result = Training.import_airtable(airtable_training)

    if result.class == String
      redirect_to trainings_path
      flash[:alert] = "#{result}"
    else
      redirect_to training_path(result)
    end
  end

  def export_training_to_airtable
    authorize @training

    UpdateAirtableJob.perform_async(@training, true)

    respond_to do |format|
      format.js { flash.now[:notice] = 'Updating... Please wait a few moments for the changes to appear in Airtable' }
    end
  end


  ##########
  ## MISC ##
  ##########

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

  def training_sessions_list
    training = Training.find(params[:training_id])
    authorize training

    sessions = params[:empty] == 'true' ? training.sessions.where_not_exists(:workshops) : training.sessions
    sessions = sessions.order(date: :asc).pluck(:id, :title)

    # render json: sessions
    render partial: 'shared/tools/training_sessions_list', locals: { elements: sessions }
  end


  private

  def set_training
    @training = Training.find(params[:id])
  end

  def training_params
    params.require(:training).permit(:title, :client_contact_id, :mode, :satisfaction_survey, :unit_price, :vat)
  end

  def search_trainings
    trainings = policy_scope(Training)

    # If user in team SEVEN
    if ['super_admin', 'admin', 'project manager'].include?(current_user.access_level)
      # Search trainings
      if params[:search].present? && params.dig(:search, :title) != ''
        trainings = Training.search_by_title_and_company("#{params.dig(:search, :title)}")
      end

      # Search trainings involving selected user
      if params[:user].present? || params.dig(:search, :user).present?

        user_id = params[:user].presence || params.dig(:search, :user)

        trainings = trainings.where_exists(:training_ownerships, user_id: user_id).or(trainings.where_exists(:session_trainers, user_id: user_id))
      end

    # If user is Sevener
    else
      trainings = trainings.where_exists(:session_trainers, user_id: current_user.id)
      # Search trainings involving current user (Sevener)
      if params[:search].present?
        trainings = trainings.search_by_title_and_company("#{params[:search][:title]}")
      # Trainings index involving current user (Sevener)
      end
    end

    return trainings
  end

  def trainings_ordered(trainings, mode)
    if mode == 'upcoming'
      trainings.where_exists(:sessions, 'date >= ?', Date.today).sort_by{|y| y.next_session}
    elsif mode == 'completed'
      trainings.where_exists(:sessions).where_not_exists(:sessions, 'date >= ?', Date.today).where_not_exists(:sessions, date: nil).sort_by{|y| y.next_session}.reverse
    elsif mode == 'all'
      # trainings.reject{|x| x.end_time.present?} + trainings.reject{|y| !y.end_time.present?}.sort_by{|z| z.end_time}.reverse
      trainings.sort_by{|x| x.end_time || Date.new(1970)}
    end
  end
end
