# frozen_string_literal: true

class Tools::SelectAutocompleteComponent < ViewComponent::Base
  def initialize(path:, additional_params: '',width:, menu_max_height: '', placeholder: '', input_name: '', default_value: [], data_action_input: '', data_action_select: '', klasses: '', initial_search: false)
    @path = path
    @additional_params = additional_params
    @width = width
    @menu_max_height = menu_max_height
    @placeholder = placeholder
    @input_name = input_name
    @default_value = default_value
    @data_action_input = data_action_input
    @data_action_select = data_action_select
    @klasses = klasses
    @initial_search = initial_search
  end
end
