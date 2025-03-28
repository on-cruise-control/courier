class Stark::StarkMessageService < Stark::BaseService
  def send_message(question:, session_id: '1a27f8a9-ec80-4609-b129-8851eb9606a5', dealership_id: 1)
    raise ArgumentError, 'Question is required' if question.to_s.strip.empty?
    raise ArgumentError, 'Session ID is required' if session_id.to_s.strip.empty?

    session_id = session_id.to_s
    payload = { question: question, session_id: session_id, dealership_id: dealership_id }
    send_request(payload)
  end
end
