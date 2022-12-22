# frozen_string_literal: true

class Tools::RadioCollectionComponent < ViewComponent::Base
  def initialize(elements: [], klasses: '', horizontal: false, input_name: '', data_action_check: '', checked: '', color: 'yellow')
    @elements = elements
    @klasses = klasses
    @horizontal = horizontal
    @input_name = input_name
    @data_action_check = data_action_check
    @checked = checked
    @color = color
  end
end
