class OblivionsController < ApplicationController
  before_action :set_oblivion, only: [:show, :edit, :update, :destroy]

  def index

  end

  def show

  end

  def new
    @training = Training.find(params[:training_id])
    @oblivion = Oblivion.new
    authorize @oblivion
  end

  def create_oblivion
    raise
  end

  private

  def set_oblivion
    @oblivion = Oblivion.find(params[:id])
  end

  def workshop_params
    params.require(:oblivion).permit(:session_id, :title)
  end
end
