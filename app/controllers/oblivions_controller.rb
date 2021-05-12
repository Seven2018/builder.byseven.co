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
    session = Session.find(params[:create_oblivion][:session_id])
    @oblivion = Oblivion.new(title: "Oblivion for #{session.training.client_contact.client_company.name} - #{session.training.title} - #{session.date.strftime('%d/%m/%Y')}", session_id: session.id)
    authorize @oblivion
    if @oblivion.save
      respond_to do |format|
        format.js
      end
    end
  end

  private

  def set_oblivion
    @oblivion = Oblivion.find(params[:id])
  end

  def workshop_params
    params.require(:oblivion).permit(:session_id, :title)
  end
end
