class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if ['super_admin', 'admin', 'training manager'].include? user.access_level
        scope.all
      else
        raise Pundit::NotAuthorizedError, 'not allowed to view this action'
      end
    end
  end

  def create?
    check_access_seven
  end

  def show?
    check_access
  end

  def update?
    check_access
  end

  def destroy?
    check_access_seven
  end

  def airtable_create_user?
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
