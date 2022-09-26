# frozen_string_literal: true

class ImpersonationsController < ApplicationController
  before_action :verify_user_is_admin
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @users = User.where(user_params)

    search_name = params.dig(:search, :name)
    search_access_level = params.dig(:search, :access_level)&.downcase&.gsub(' ', '_')
    page_index = (params.dig(:search, :page).presence || 1).to_i

    @users = @users.search_users(search_name) if search_name.present?
    @users = @users.where(access_level: search_access_level) if search_access_level.present?

    @total_users = @users.count

    @users = @users.order(created_at: :desc).page(page_index)

    @any_more = @users.count * page_index < @total_users

    respond_to do |format|
      format.html
      format.js
    end
  end

  def impersonate
    user = User.find(params[:id])
    impersonate_user(user)
    redirect_to after_sign_in_path_for(user)
  end

  def stop_impersonating
    stop_impersonating_user
    redirect_to root_path
  end

  private

  def verify_user_is_admin
    redirect_to root_path, notice: 'Espace réservé aux admins' unless true_user.super_admin? || current_user.super_admin?
  end

  def user_params
    {
      firstname: params[:firstname],
      lastname: params[:lastname],
      email: params[:email],
      access_level: params[:access_level]
    }.compact
  end
end
