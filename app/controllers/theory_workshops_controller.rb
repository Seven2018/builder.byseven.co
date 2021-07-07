class TheoryWorkshopsController < ApplicationController

  # Manage linked theories through a checkbox interface (workshops/show)
  def manage_linked_theories
    skip_authorization
    @workshop = Workshop.find(params[:workshop_id])
    chosen_theories = Theory.where(id: params[:workshop][:theory_ids].reject{|x| x.empty?}.map{|y| y.to_i})
    ignored_theories = Theory.all - chosen_theories
    chosen_theories.each do |theory|
      unless TheoryWorkshop.find_by(workshop_id: @workshop.id, theory_id: theory.id).present?
        TheoryWorkshop.create(workshop_id: @workshop.id, theory_id: theory.id)
      end
    end
    TheoryWorkshop.where(workshop_id: @workshop.id, theory_id: ignored_theories.map(&:id)).destroy_all
    respond_to do |format|
      format.html {redirect_back(fallback_location: root_path)}
      format.js
    end
  end

  # Delete selected theory_workshop (workshops/show)
  def remove_linked_theory
    skip_authorization
    workshop = Workshop.find(params[:workshop_id])
    theory = Theory.find(params[:theory_workshop][:theory])
    theory_workshop = TheoryWorkshop.where(workshop: workshop).where(theory: theory)
    theory_workshop.first.destroy
    redirect_back(fallback_location: root_path)
  end
end
