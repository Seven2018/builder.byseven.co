class SessionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create?
    check_access_seven
  end

  def show?
    check_access
  end

  def update?
    check_access_seven
  end

  def update_ajax?
    check_access_seven
  end

  def destroy?
    check_access_seven
  end

  def viewer?
    check_access
  end

  def copy?
    check_access_seven
  end

  def copy_content?
    check_access_seven
  end

  def copy_form?
    check_access_seven
  end

  def presence_sheet?
    check_access_seven
  end

  def import_attendees?
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
