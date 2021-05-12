class OblivionPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create?
    check_access_seven
  end

  def show?
    check_access_seven
  end

  def update?
    check_access_seven
  end

  def destroy?
    check_access_seven
  end

  def create_oblivion_message?
    check_access_seven
  end

  private

  def check_access_seven
    ['super admin', 'admin', 'training manager'].include? user.access_level
  end
end
