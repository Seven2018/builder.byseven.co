json.theories do
  json.array! @theories do |theory|
    json.name theory.name
    json.url theory_path(theory)
    json.id theory.id
  end
end
