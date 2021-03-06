class ClientCompaniesController < ApplicationController
before_action :set_clientcompany, only: [:show, :edit, :update, :destroy]
before_action :authenticate_user!, except: [:new_attendees, :create_attendees]

  # Index with "search" option
  def index
    params[:search] ? @client_companies = policy_scope(ClientCompany).where("lower(name) LIKE ?", "%#{params[:search][:name].downcase}%").order(name: :asc) : @client_companies = policy_scope(ClientCompany).order(name: :asc)
  end

  def show
    authorize @client_company
    @client_contacts = ClientContact.where(client_company: @client_company)
  end

  def new
    @client_company = ClientCompany.new
    authorize @client_company
  end

  def create
    reference = (ClientCompany.where.not(reference: nil).order(id: :asc).last.reference[-8..-1].to_i + 1).to_s.rjust(8, '0') if ClientCompany.all.count != 0
    @client_company = ClientCompany.new(clientcompany_params.merge(referece: reference))
    authorize @client_company
    @client_company.save ? (redirect_to client_company_path(@client_company)) : (render :new)
  end

  def edit
    authorize @client_company
  end

  def update
    authorize @client_company
    @client_company.update(clientcompany_params)
    @client_company.save ? (redirect_to client_company_path(@client_company)) : (render "_edit")
  end

  def destroy
    @client_company.destroy
    authorize @client_company
    redirect_to client_companies_path
  end

  def new_attendees
    skip_authorization
    @client_company = ClientCompany.find(params[:client_company_id])
  end

  def create_attendees
    skip_authorization
  end

  private

  def set_clientcompany
    @client_company = ClientCompany.find(params[:id])
  end

  def clientcompany_params
    params.require(:client_company).permit(:name, :address, :zipcode, :city, :description, :logo, :client_company_type, :opco_id, :unit_price, :reference, :siret)
  end
end
