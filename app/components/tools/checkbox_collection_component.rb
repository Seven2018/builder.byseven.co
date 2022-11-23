# frozen_string_literal: true

class Tools::CheckboxCollectionComponent < ViewComponent::Base
  def initialize(elements: [], klasses: '', input_name: '', data_action_check: '', select_all: true)
    @elements = elements
    @klasses = klasses
    @input_name = input_name
    @data_action_check = data_action_check
    @select_all = select_all
  end
end
