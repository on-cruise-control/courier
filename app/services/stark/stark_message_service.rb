class Stark::StarkMessageService < Stark::BaseService
  def send_message(question:, session_id:, dealership_id:)
    session_id = session_id.to_s
    payload = { question: question, session_id: session_id, dealership_id: dealership_id }
    send_request(payload)
  end
end
