module Users::Access
  def access_level_preset
    ACCESS_LEVEL_LABELS[access_level]
  end

  ACCESS_LEVEL_LABELS = {
    "sevener" => "Sevener",
    "sevener+" => "Sevener +",
    "training_manager" => "Training Manager",
    "admin" => "Admin",
    "super_admin" => "Super Admin"
  }
end
