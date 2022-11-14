# frozen_string_literal: true

class Buttons::OptionsButtonComponent < ViewComponent::Base
  def initialize(vertical: false)
    @vertical = vertical
  end
end
