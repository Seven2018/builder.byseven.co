json.contents do
  json.array! @contents do |content|
    json.title content.title
    json.url content_path(content)
    json.id content.id
  end
end
