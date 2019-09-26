class TrainingsController < ApplicationController
  before_action :set_training, only: [:show, :edit, :update, :destroy]

  def index
    @sessions = Session.all
    @session_trainer = SessionTrainer.new
    if ['super admin', 'admin', 'project manager'].include?(current_user.access_level)
      @trainings = policy_scope(Training).order('start_date ASC')
    else
      @trainings = policy_scope(Training)
      @trainings = []
      @sessions.each do |session|
        @trainings << session.training if session.users.include?(current_user)
      end
    end
  end

  def index_week
    @trainings = Training.all
    @sessions = Session.all
    authorize @trainings
  end

  def index_month
    @trainings = Training.all
    @sessions = Session.all
    authorize @trainings
  end

  def show
    authorize @training
    @training_ownership = TrainingOwnership.new
    @session = Session.new
    @users = User.all
  end

  def new
    @training = Training.new
    @training_ownership = TrainingOwnership.new
    @clients = ClientContact.all
    authorize @training
  end

  def create
    @training = Training.new(training_params)
    @training_ownership = TrainingOwnership.new(user: current_user, training: @training)
    authorize @training
    if @training.save && @training_ownership.save
      redirect_to training_path(@training)
    else
      render :new
    end
  end

  def edit
    authorize @training
  end

  def update
    authorize @training
    @training.update(training_params)
    if @training.save
      redirect_to training_path(@training)
    else
      render :edit
    end
  end

  def destroy
    @training.destroy
    authorize @training
    redirect_to trainings_path
  end

  private

  def set_training
    @training = Training.find(params[:id])
  end

  def training_params
    params.require(:training).permit(:title, :start_date, :end_date, :client_contact_id, :mode)
  end
end
