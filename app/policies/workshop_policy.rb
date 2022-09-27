class WorkshopPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create?
    check_access_sevener_plus
  end

  def show?
    check_access
  end

  def update?
    check_access_sevener_plus
  end

  def destroy?
    check_access_sevener_plus
  end

  def move?
    check_access_seven
  end

  def move_up?
    check_access_sevener_plus
  end

  def move_down?
    check_access_sevener_plus
  end

  def save?
    check_access_seven
  end

  def viewer?
    check_access_seven
  end

  def copy_form?
    check_access_seven
  end

  def copy?
    check_access_seven
  end

  private

  def check_access_seven
    ['super_admin', 'admin', 'training manager'].include? user.access_level
  end

  def check_access_sevener_plus
    ['super_admin', 'admin', 'training manager', 'sevener+'].include? user.access_level
  end

  def check_access
    ['super_admin', 'admin', 'training manager', 'sevener+', 'sevener'].include? user.access_level
  end
end
