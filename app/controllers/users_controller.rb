class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy]
  before_action :authenticate_user!, except: [:reset_password]

  ##########
  ## CRUD ##
  ##########

  def index
    @users = policy_scope(User).active

    search_name = params.dig(:search, :name)
    search_access_level = params.dig(:search, :access_level)&.downcase&.gsub(' ', '_')
    page_index = (params.dig(:search, :page).presence || 1).to_i

    @users = @users.search_users(search_name) if search_name.present?
    @users = @users.where(access_level: search_access_level) if search_access_level.present?

    @total_users = @users.count

    @users = @users.order(lastname: :asc).page(page_index)

    @any_more = @users.count * page_index < @total_users

    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @user = User.new
    authorize @user
  end

  def create
    @user = User.new(user_params)
    authorize @user
    if @user.save
      @user.export_airtable_user
      airtable_user_photo = OverviewUser.all(filter: "{Email} = '#{@user.email}'")&.first['Photo']
      @user.update(picture: airtable_user_photo&.first['url']) if airtable_user_photo.present?
      redirect_to user_path(@user)
    else
      render :new
    end
  end

  def show
    if ['super_admin', 'admin', 'training manager'].include?(current_user.access_level)
      @user = User.find(params[:id])
    elsif current_user.access_level == 'HR'
      @user = User.where(client_company_id: current_user.client_company_id).find(params[:id])
    else
      @user = current_user
    end
    authorize @user

    trainings = Training.where_exists(:session_trainers, user_id: @user.id)
    @upcoming_trainings = trainings.where_exists(:sessions, 'date >= ?', Date.today)
    @completed_trainings = trainings.where_not_exists(:sessions, 'date >= ?', Date.today)
  end

  def edit
    authorize @user
  end

  def update
    authorize @user
    @user.update(user_params)
    if @user.save
      @user.export_airtable_user
      redirect_to user_path(@user)
    else
      render "_edit"
    end
  end

  def destroy
    authorize @user
    @user.destroy
    redirect_to users_path
  end


  ##############
  ## PASSWORD ##
  ##############

  def reset_password
    skip_authorization

    @user = User.find_by(email: params.dig(:user, :email))
    @user.reset_password! if @user

    respond_to do |format|
      format.js
    end
  end

  ##############
  ## AIRTABLE ##
  ##############

  def airtable_create_user
    user = OverviewUser.find(params[:record_id])
    user_params = {firstname: user['Firstname']&.capitalize, lastname: user['Lastname']&.upcase, email: user['Email']&.downcase, password: 'Seven2021', picture: (user['Photo'] ? user['Photo'].first['url'] : nil)}
    builder_user = user['Builder_id'].present? ? User.find_by(id: user['Builder_id']) : User.find_by(email: user['Email'])
    skip_authorization

    builder_user.present? ? builder_user&.update(user_params) : builder_user = User.new(user_params)

    if user['Status'] == 'Seven'
      builder_user.access_level = 'admin'
    else
      builder_user.access_level = 'sevener'
    end

    if user['On / Off'] == 'Off'
      builder_user.status = :inactive
    else
      builder_user.status = :active
    end

    if builder_user.save
      user['Builder_id'] = builder_user.id
      user['Builder Account'] = true
      user.save
      redirect_to user_path(builder_user)
    else
      redirect_to users_path
      flash[:alert] = 'A problem has occured. Please contact your administrator.'
    end
  end

  #########################
  ## SEARCH AUTOCOMPLETE ##
  #########################

  def users_search
    skip_authorization

    @users = User.all.active.order(lastname: :asc)

    @users = @users.ransack(firstname_or_lastname_cont: params[:search]).result(distinct: true).map{|x| [x.id, x.fullname]}

    render partial: 'shared/tools/select_autocomplete', locals: { elements: @users }
  end

  #########################

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:firstname, :lastname, :email, :password, :access_level, :picture, :linkedin, :description, :rating, :client_company_id)
  end
end
