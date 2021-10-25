class SessionTrainerPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def link_to_session?
    check_access_seven
  end

  def link_to_training?
    check_access_seven
  end

  def update_calendar?
    check_access_seven
  end

  private

  def check_access_seven
    ['super admin', 'admin', 'training manager'].include? user.access_level
  end
end
