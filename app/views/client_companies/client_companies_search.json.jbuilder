json.client_companies do
  json.array! @client_companies do |client_company|
    json.name client_company.name
    json.url client_company_path(client_company)
    json.id client_company.id
  end
end
