class FormPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if ['super_admin', 'admin', 'training manager'].include? user.access_level
        scope.all
      else
        raise Pundit::NotAuthorizedError, 'not allowed to view this action'
      end
    end
  end

  def index
    check_access
  end

  def create?
    check_access
  end

  def show?
    true
  end

  def update?
    check_access
  end

  private

  def check_access
    ['super_admin', 'admin', 'training manager'].include? user.access_level
  end
end
