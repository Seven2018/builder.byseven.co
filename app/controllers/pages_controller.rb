class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home, :survey, :kea_partners]

  def home
  end

  def overlord
  end

  def kea_partners_c
  end

  def survey
    redirect_to 'https://docs.google.com/forms/d/1knOYJWvoVV7T3IVCbNqoMtTbgMiDG6zroZSPrRJm5vY/edit'
  end

  def numbers_activity
    if params[:numbers_activity].present?
      @starts_at = params[:numbers_activity][:starts_at]
      @ends_at = params[:numbers_activity][:ends_at]
      @trainings = Training.numbers_scope(@starts_at, @ends_at)
    else
      @starts_at = Date.today.beginning_of_year
      @ends_at = Date.today
      @trainings = Training.numbers_scope
    end
    respond_to do |format|
      format.html
      format.csv { send_data Training.where(id: @trainings.map(&:id)).numbers_activity_csv(params[:starts], params[:ends]), filename: "Numbers Activity #{params[:starts].split('-').join()} - #{params[:ends].split('-').join()}" }
    end
  end

  def numbers_sales
    if params[:numbers_sales].present?
      @starts_at = params[:numbers_sales][:starts_at]
      @ends_at = params[:numbers_sales][:ends_at]
      @invoices = InvoiceItem.numbers_scope(@starts_at, @ends_at)
    else
      @starts_at = Date.today.beginning_of_year
      @ends_at = Date.today
      @invoices = InvoiceItem.numbers_scope(@starts_at, @ends_at)
    end
  end
end


