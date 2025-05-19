class ConversationHandoff::SendHandoffNotificationsJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    return if conversation.blank?

    AdministratorNotifications::ConversationHandoffMailer.notify_handoff(conversation).deliver_later
    AgentNotifications::ConversationHandoffMailer.notify_handoff(conversation).deliver_later
  end
end
