class VehiclePartsEscalationNotificationJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, emails, customer_data = nil, message = nil)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    Conversations::SummaryService.new(
      conversation: conversation,
      force_refresh: true,
      skip_rate_limit: true
    ).perform

    AgentNotifications::VehiclePartsEscalationMailer.escalation_notification(
      emails: emails,
      conversation: conversation,
      customer_data: customer_data,
      message: message
    ).deliver_now

    Sms::VehiclePartsEscalationNotificationService.new(
      conversation: conversation,
      emails: emails,
      customer_data: customer_data
    ).perform
  end
end
