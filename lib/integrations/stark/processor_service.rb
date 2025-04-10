class Integrations::Stark::ProcessorService < Integrations::BotProcessorService
  include HTTParty
  AUTH_TOKEN = 'i6NpaCOX7aDXVWfHsnxgJKYuDftBfhxb'.freeze
  pattr_initialize [:event_name!, :hook!, :event_data!]

  def hook
    @hook ||= agent_bot
  end

  def agent_bot
    @agent_bot ||= hook
  end

  def perform
    return unless can_process_message?

    process_conversation
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: agent_bot.account).capture_exception
  end

  private

  def can_process_message?
    valid_event_name? &&
      agent_bot.outgoing_url.present? &&
      event_data[:message].incoming?
  end

  def process_conversation
    return unless update_conversation_status
    return unless should_run_processor?(event_data[:message])

    process_stark_response
  end

  def update_conversation_status
    current_conversation.update(status: :pending) if current_conversation.open?
    true
  end

  def current_conversation
    @current_conversation ||= event_data[:message].conversation
  end

  def process_stark_response
    response = get_stark_response(current_conversation, event_data[:message].content)
    return if response.blank?

    handle_response(response)
  end

  def handle_response(response)
    create_bot_response_message(current_conversation, response['content']) if response['content'].present?
    process_action(event_data[:message], response['action']) if response['action'].present?
  end

  def valid_event_name?
    %w[message.created message.updated].include?(event_name)
  end

  def get_stark_response(conversation, content)
    response = HTTParty.post(
      agent_bot.outgoing_url,
      body: stark_payload(conversation, content).to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{AUTH_TOKEN}"
      }
    )
    return unless response.code == 200

    parsed_response = JSON.parse(response.body)
    {
      'content' => parsed_response['body']['data']['answer'],
      'action' => parsed_response['body']['data']['human_redirect'] ? 'handoff' : nil
    }
  end

  def stark_payload(conversation, content)
    {
      question: content,
      session_id: conversation.account_id,
      dealership_id: '177b4e57-dacf-46c7-b582-08886aa81fd4', # integer_to_uuid(conversation.id)
      conversation_id: conversation.id
    }
  end

  def integer_to_uuid(integer)
    srand(integer)
    uuid = SecureRandom.uuid
    srand
    uuid
  end

  def conversation
    @conversation ||= event_data[:message].conversation
  end

  def create_bot_response_message(conversation, content)
    conversation.messages.create!(
      content: content,
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: agent_bot
    )
  end
end
