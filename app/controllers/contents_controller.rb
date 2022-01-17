class ContentsController < ApplicationController
  before_action :set_content, only: [:show, :edit, :update, :destroy]

  def index
    params[:search] ? @contents = policy_scope(Content).where("lower(title) LIKE ?", "%#{params[:search][:title].downcase}%").order(title: :asc) : @contents = policy_scope(Content).order(title: :asc)
    @contents = policy_scope(Content)
    @themes = Theme.all
  end

  def contents_search
    skip_authorization
    @contents = Content.ransack(title_cont: params[:search]).result(distinct: true).limit(5)
  end

  def show
    authorize @content
    content_modules = @content.content_modules.order(position: :asc)
    if content_modules.map(&:position) != (1..content_modules.count).to_a
      i = 1
      content_modules.each{|x| x.update position: i; i += 1}
    end
    @theory_content = TheoryContent.new
  end

  def new
    @content = Content.new
    authorize @content
  end

  def create
    @content = Content.new(content_params)
    authorize @content
    @content.save ? (redirect_to content_path(@content)) : (render :new)
  end

  def edit
    authorize @content
  end

  def update
    authorize @content
    @content.update(content_params)
    @content.save ? (redirect_to content_path(@content)) : (render "_edit")
  end

  def destroy
    authorize @content
    @content.destroy
    redirect_to contents_path
  end

  private

  def set_content
    @content = Content.find(params[:id])
  end

  def content_params
    params.require(:content).permit(:title, :duration, :description, :theme_id)
  end
end
