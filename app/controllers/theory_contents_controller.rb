class TheoryContentsController < ApplicationController

  # Manage linked theories through a checkbox interface (contents/show)
  def manage_linked_theories
    skip_authorization
    @content = Content.find(params[:content_id])
    chosen_theories = Theory.where(id: params[:content][:theory_ids].reject{|x| x.empty?}.map{|y| y.to_i})
    ignored_theories = Theory.all - chosen_theories
    chosen_theories.each do |theory|
      unless TheoryContent.find_by(content_id: @content.id, theory_id: theory.id).present?
        TheoryContent.create(content_id: @content.id, theory_id: theory.id)
      end
    end
    TheoryContent.where(content_id: @content.id, theory_id: ignored_theories.map(&:id)).destroy_all
    respond_to do |format|
      format.html {redirect_back(fallback_location: root_path)}
      format.js
    end
  end

  # Delete selected theory_content (contents/show)
  def remove_linked_theory
    skip_authorization
    @content = Content.find(params[:content_id])
    theory = Theory.find(params[:theory_id])
    theory_content = TheoryContent.find_by(content_id: @content.id, theory_id: theory.id)
    theory_content.destroy
    respond_to do |format|
      format.html {redirect_back(fallback_location: root_path)}
      format.js
    end
  end
end
