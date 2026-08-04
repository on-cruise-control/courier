class NegativeSentimentEscalationJob < ApplicationJob
  queue_as :low

  def perform(conversation_id, emails)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    Conversations::SummaryService.new(
      conversation: conversation,
      force_refresh: true,
      skip_rate_limit: true
    ).perform

    AgentNotifications::EscalationMailer.negative_sentiment_notification(
      emails: emails,
      conversation: conversation
    ).deliver_now

    Sms::NegativeSentimentEscalationService.new(
      conversation: conversation,
      emails: emails
    ).perform
  end
end
