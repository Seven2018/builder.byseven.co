# frozen_string_literal: true

class Tools::TabsSystemComponent < ViewComponent::Base
  def initialize(tabs_names: [], klasses: '')
    @tabs_names = tabs_names
    @klasses = klasses
  end
end
