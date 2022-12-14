class TrainingPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if ['super_admin', 'admin', 'training manager', 'sevener+', 'sevener'].include? user.access_level
        scope.all
      else
        raise Pundit::NotAuthorizedError, 'not allowed to view this action'
      end
    end
  end

  ##########
  ## CRUD ##
  ##########

  def index_completed?
    check_access
  end

  def create?
    check_access_seven
  end

  def show?
    check_access
  end

  def show_session_content?
    check_access
  end

  def update?
    check_access_seven
  end

  def destroy?
    check_access_seven
  end


  ##################
  ## EMAIL SYSTEM ##
  ##################

  def trainer_notification_email?
    check_access_seven
  end


  ###############
  ## ATTENDEES ##
  ###############

  def import_attendees?
    check_access_seven
  end


  ##############
  ## AIRTABLE ##
  ##############

  def export_training_to_airtable?
    check_access_seven
  end

  ##########
  ## MISC ##
  ##########

  def copy?
    check_access_seven
  end

  def invoice_form?
    check_access
  end

  def training_sessions_list?
    check_access_seven
  end

  private

  def check_access_seven
    ['super_admin', 'admin', 'training manager'].include? user.access_level
  end

  def check_access
    ['super_admin', 'admin', 'training manager', 'sevener+', 'sevener'].include? user.access_level
  end
end
