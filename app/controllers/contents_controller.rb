class ContentsController < ApplicationController
  before_action :set_content, only: [:show, :edit, :update, :destroy]

  ##########
  ## CRUD ##
  ##########

  def index
    @contents = policy_scope(Content)

    @contents = @contents.joins(:theme).order('themes.name ASC', 'title ASC').group_by(&:theme)
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

  #####################
  ## SEARCH CONTENTS ##
  #####################

  def contents_search
    skip_authorization

    if params.dig(:search, :title) == ""
      @contents = Content.all
    elsif params.dig(:search, :deep_mode).present?
      @contents = Content.deep_search(params.dig(:search, :title))
    else
      @contents = Content.search_by_title(params.dig(:search, :title))
    end

    @contents = @contents.joins(:theme).order('themes.name ASC', 'title ASC').group_by(&:theme)

    respond_to do |format|
      format.js
    end
  end

  private

  def set_content
    @content = Content.find(params[:id])
  end

  def content_params
    params.require(:content).permit(:title, :duration, :description, :theme_id)
  end
end
