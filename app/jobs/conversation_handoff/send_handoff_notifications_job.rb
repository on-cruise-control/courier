class ConversationHandoff::SendHandoffNotificationsJob < ApplicationJob
  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    # Send notification to administrators
    AdministratorNotifications::ConversationHandoffMailer.notify_handoff(conversation).deliver_later

    # Send notification to sales representatives
    AgentNotifications::ConversationHandoffMailer.notify_handoff(conversation).deliver_later
  end
end
