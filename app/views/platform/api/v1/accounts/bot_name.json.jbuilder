json.location request.url
json.body do
  json.account_id @resource.id
  json.dealership_id @resource.dealership_id
  json.bot_name @resource.bot_name
end
json.metadata do
  json.status_code 200
end
