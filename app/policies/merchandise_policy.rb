class MerchandisePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create?
    check_access
  end

  def show?
    check_access_open
  end

  def edit?
    check_access
  end

  def update?
    check_access
  end

  def destroy?
    check_access
  end

  private

  def check_access_open
    ['super admin', 'admin', 'training manager', 'HR', 'employee'].include? user.access_level
  end

  def check_access
    ['super admin', 'admin', 'training manager'].include? user.access_level
  end
end