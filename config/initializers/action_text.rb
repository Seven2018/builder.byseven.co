Rails.application.config.after_initialize do
  ActionText::ContentHelper.allowed_attributes.add "style"
  ActionText::ContentHelper.allowed_tags.add "span"
end
