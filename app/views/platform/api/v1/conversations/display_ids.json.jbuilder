json.location request.url
json.body do
  json.array! @conversations do |conversation|
    json.conversation_id conversation.id
    json.display_id conversation.display_id
  end
end
json.metadata do
  json.status_code 200
end
