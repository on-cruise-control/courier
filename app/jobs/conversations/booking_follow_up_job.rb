class Conversations::BookingFollowUpJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.nil?

    conversation.update_column(:booking_follow_up_jid, nil)

    return if conversation.is_spam || conversation.is_blacklisted

    dealership_name = conversation.account.name
    content = "Hey I'm just checking in from #{dealership_name}. Has someone from our team reached out to you to book an appointment?"

    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: content,
      content_attributes: { booking_follow_up: true },
      sender: conversation.inbox.agent_bot.presence || nil
    )
  end
end
