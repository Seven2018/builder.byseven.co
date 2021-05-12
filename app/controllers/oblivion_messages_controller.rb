class OblivionMessagesController < ApplicationController

  def create_oblivion_message
    raise
    @oblivion = Oblivion.find(params[:oblivion_id])
    @oblivion_message = OblivionMessage.new(titre: params[:create_oblivion_message][:title], content: params[:create_oblivion_message][:content], oblivion_id: @oblivion.id, position: params[:create_oblivion_message][:position])
    respond_to do |format|
      format.js
    end
  end
end
