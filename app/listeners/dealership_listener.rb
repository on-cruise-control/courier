# frozen_string_literal: true

class DealershipListener < BaseListener
  def conversation_created(event)
    conversation, _account = extract_conversation_and_account(event)
    return if conversation.contact.blank?

    Dealership::CustomerCreateService.new(conversation.contact, inbox: conversation.inbox, conversation: conversation).perform
  end
end
