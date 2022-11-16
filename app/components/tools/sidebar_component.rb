# frozen_string_literal: true

class Tools::SidebarComponent < ViewComponent::Base
  def initialize(title:, width: '25rem', side: 'right', hideable: true, button_klasses: '', klasses: '')
    @title = title
    @width = width
    @side = side
    @hideable = hideable
    @button_klasses = button_klasses
    @klasses = klasses
  end
end
