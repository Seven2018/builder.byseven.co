class UsersController < ApplicationController
  before_action :set_user, only: [:edit, :update, :destroy]

  def index
    index_function(policy_scope(User))
  end

  def users_search
    skip_authorization
    @users = User.ransack(firstname_or_lastname_cont: params[:search]).result(distinct: true).limit(5)
    # respond_to do |format|
    #   format.html{}
    #   format.json {
    #     # render json: @users
    #   }
    # end
    # render json: {users: @users.map{|x| x.to_json(:only => [:id], methods: :fullname)}}
  end

  def show
    if ['super admin', 'admin', 'training manager'].include?(current_user.access_level)
      @user = User.find(params[:id])
    elsif current_user.access_level == 'HR'
      @user = User.where(client_company_id: current_user.client_company_id).find(params[:id])
    else
      @user = current_user
    end
    authorize @user
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

  # Allows to scrape data from the current user Linkedin profile
  def linkedin_scrape
    skip_authorization
    oauth = LinkedIn::OAuth2.new
    url = oauth.auth_code_url
    redirect_to "#{url}"
  end

  def linkedin_scrape_callback
    skip_authorization
    oauth = LinkedIn::OAuth2.new
    code = params[:code]
    access_token = oauth.get_access_token(code)
    api = LinkedIn::API.new(access_token)
    client = RestClient
    # Updates User picture with his(her) Linkedin profile picture.
    url = 'https://api.linkedin.com/v2/me?projection=(id,firstName,lastName,profilePicture(displayImage~:playableStreams))'
    res = RestClient.get(url, Authorization: "Bearer #{access_token.token}")
    picture_url = res.body.split('"').select{ |i| i[/https:\/\/media\.licdn\.com\/dms\/image\/.*/]}.last
    current_user.update(picture: picture_url)

    redirect_to user_path(current_user)
  end

  # AIRTABLE

  def airtable_create_user
    user = OverviewUser.find(params[:record_id])
    new_user = User.new(firstname: user['Firstname'], lastname: user['Lastname'], email: user['Email'], password: 'Seven2021')
    authorize new_user
    if user['Status'] == 'Seven'
      new_user.access_level = 'admin'
    else
      new_user.access_level = 'sevener'
    end
    if new_user.save
      user['Builder_id'] = new_user.id
      user['Builder Account'] = true
      user.save
      redirect_to user_path(new_user)
    else
      redirect_to users_path
      flash[:alert] = 'An problem has occured. Please contact your administrator.'
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:firstname, :lastname, :email, :password, :access_level, :picture, :linkedin, :description, :rating, :client_company_id)
  end

  def index_function(parameter)
    if params[:search]
      @users = parameter
      @users = User.all.search_by_name("#{params[:search][:name]}")
      @users = @users.sort_by{ |user| user.lastname } if @users.present?
    else
      @users = parameter.order(lastname: :asc)
    end
  end
end
