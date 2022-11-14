class SessionsController < ApplicationController
  before_action :set_session, only: [:show, :edit, :update, :update_ajax, :destroy, :viewer, :copy_form, :copy, :copy_content, :presence_sheet, :import_attendees]
  skip_before_action :verify_authenticity_token, only: [:update_ajax]

  def new
    @training = Training.find(params[:training_id])
    @session = Session.new
    authorize @session
  end

  def create
    @training = Training.find(params[:training_id])
    @session = Session.new(session_params)
    authorize @session
    @session.training = @training
    if @session.save
      UpdateAirtableJob.perform_async(@training)
      redirect_to training_path(@training)
    end
  end

  # Shows an InvoiceItem in html or pdf version
  def show
    authorize @session
    @session_trainer = SessionTrainer.new
    # @comment = Comment.new
    workshops = @session.workshops.order(position: :asc)
    if workshops.map(&:position) != (1..@session.workshops.count).to_a
      i = 1
      workshops.each{|x| x.update position: i; i += 1}
    end
    respond_to do |format|
      format.html
      format.pdf do
        render(
          pdf: "#{@session.title}",
          layout: 'pdf.html.erb',
          template: 'sessions/show',
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
    @training = Training.find(params[:training_id])
    authorize @session
  end

  def update
    authorize @session

    prev_date = @session.date
    prev_start = @session.start_time
    prev_end = @session.end_time
    @session.update(session_params)

    if @session.save && (params[:session][:date].present?)
      UpdateAirtableJob.perform_async(@session.training, true)
      params[:session][:session_page].present? ? (redirect_to training_path(@session.training, page: params[:session][:session_page], change: true)) : (redirect_to training_path(@session.training, change: true))
    end
  end

  def update_ajax
    authorize @session

    training = @session.training
    @session_number = params.dig(:session, :session_number)

    @session.update(session_params)
    @redirect_from = params[:redirect_from]
    if @session.save

      UpdateAirtableJob.perform_async(@session.training, true)

      respond_to do |format|
        format.html {redirect_to training_path(training)}
        format.js
      end
    end
  end

  def destroy
    @training = Training.find(params[:training_id])
    authorize @session
    @session.destroy
    UpdateAirtableJob.perform_async(@training, true)
    redirect_to training_path(@training)
  end

  # Shows a Session in "viewer mode"
  def viewer
    authorize @session
  end

  def copy_form
    authorize @session
  end

  def copy
    authorize @session
    new_sessions = []

    if params[:button] == 'copy'
      training = Training.find_by(id: params[:copy][:target_training_id]) || @session.training

      for i in 1..params[:copy][:amount].to_i
        new_session = Session.new(@session.attributes.except("id", "created_at", "updated_at", "training_id", "address", "room"))
        training.sessions.empty? ? (new_session&.date = Date.today) : (new_session&.date = @session&.date)
        new_session.training_id = training.id
        new_session.address = ''
        new_session.room = ''
        new_session.training_id = training.id
        new_session.save
        new_sessions << new_session
      end
    else
      training = Training.find(params[:training_id])

      for i in 1..params[:copy][:amount].to_i
        new_session = Session.new(@session.attributes.except("id", "created_at", "updated_at"))
        new_session&.date = @session&.date
        new_session.save
        new_sessions << new_session
      end
    end

    new_sessions.each do |new_session|

      @session.workshops.order(position: :asc).each do |workshop|

        new_workshop = Workshop.create(workshop.attributes.except("id", "created_at", "updated_at", "session_id"))
        new_workshop.update(session_id: new_session.id)

        workshop.workshop_modules.order(position: :asc).each do |mod|
          new_mod = WorkshopModule.create(mod.attributes.except("id", "created_at", "updated_at", "workshop_id", "user_id"))
          new_mod.update(workshop_id: new_workshop.id)
        end

      end

    end

    redirect_to training_path(training)
  end

  def copy_content
    authorize @session

    training = Training.find(params.dig(:copy, :training_id))
    target_sessions = Session.where(id: params.dig(:copy, :target_sessions_ids).split(','))

    tar.each do |target_session|

      workshop_count = target_session.workshops.count

      @session.workshops.each do |workshop|
        new_workshop = Workshop.create(workshop.attributes.except("id", "created_at", "updated_at", "session_id"))
        new_workshop.update(session_id: target_session.id, position: workshop_count + workshop.position)
        workshop.workshop_modules.each do |mod|
          new_mod = WorkshopModule.create(mod.attributes.except("id", "created_at", "updated_at", "workshop_id", "user_id"))
          new_mod.update(workshop_id: new_workshop.id, position: mod.position)
        end
      end

    end

    redirect_to training_path(training)
  end

  def presence_sheet
    authorize @session
    respond_to do |format|
      format.pdf do
        render(
          pdf: "#{@session.title}",
          layout: 'pdf.html.erb',
          template: 'sessions/presence_sheet',
          margin: { top: 110 },
          header: { spacing: 1.51, html: { template: 'sessions/header.pdf.erb' } },
          show_as_html: params.key?('debug'),
          page_size: 'A4',
          encoding: 'utf8',
          dpi: 300,
          zoom: 1,
          viewport_size: '1280x1024'
        )
      end
    end
  end

  def import_attendees
    authorize @session
    AirtableAttendee.all.each do |attendee|
      new_attendee = Attendee.find_by(email: attendee['Email'])
      attendee['Company_id'].present? ? company_id = attendee['Company_id'] : company_id = @session.training.client_company.id
      new_attendee = Attendee.create(firstname: attendee['Firstname'], lastname: attendee['Lastname'], email: attendee['Email'], client_company_id: company_id) if new_attendee.nil?
      SessionAttendee.create(attendee_id: new_attendee.id, session_id: @session.id)
    end
    redirect_to training_session_path(@session.training, @session)
  end


  #########################
  ## SEARCH AUTOCOMPLETE ##
  #########################

  def sessions_search
    skip_authorization

    if params[:search] == ""
      @sessions = Session.all.joins(:training).order('trainings.title asc').limit(50)
    else
      @sessions = Session.search_by_title_and_training(params[:search])
      @sessions = @sessions.limit(50)
    end

    @sessions = @sessions.map{|x| [x.id, (x.training.title + ' - ' + x.title + ' - id: ' + x.id.to_s)]}.sort{|a,b| a[1] <=> b[1]}

    render partial: 'shared/tools/select_autocomplete', locals: { elements: @sessions }
  end

  private

  def set_session
    @session = Session.find(params[:id])
  end

  def session_params
    params.require(:session).permit(:title, :date, :start_time, :end_time, :training_id, :duration, :lunch_duration, :attendee_number, :description, :teaser, :image, :address, :room, :session_type, { user_ids: [] }, session_trainers_attributes: [:id, :session_id, :user_id])
  end
end
