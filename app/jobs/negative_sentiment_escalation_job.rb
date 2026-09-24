class NegativeSentimentEscalationJob < ApplicationJob
  queue_as :low

  CATEGORY_ESCALATIONS = {
    'sales_escalation' => {
      emails: :sales_comment_escalation_emails,
      mailer: AgentNotifications::SalesEscalationMailer,
      sms_service: Sms::CommentEscalationService,
      sms_category: 'sales'
    },
    'service_escalation' => {
      emails: :service_comment_escalation_emails,
      mailer: AgentNotifications::ServiceEscalationMailer,
      sms_service: Sms::CommentEscalationService,
      sms_category: 'service'
    },
    'vehicle_parts_escalation' => {
      emails: :vehicle_parts_comment_escalation_emails,
      mailer: AgentNotifications::VehiclePartsEscalationMailer,
      sms_service: Sms::CommentEscalationService,
      sms_category: 'parts'
    },
    'non_department_escalation' => {
      emails: :escalation_emails,
      mailer: AgentNotifications::EscalationMailer,
      sms_service: Sms::NegativeSentimentEscalationService
    }
  }.freeze

  def perform(conversation_id, handoff_reason, customer_data = nil)
    config = CATEGORY_ESCALATIONS[handoff_reason.to_s.strip.downcase]
    return unless config

    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.blank?

    Conversations::SummaryService.new(
      conversation: conversation,
      force_refresh: true,
      skip_rate_limit: true
    ).perform

    recipients = conversation.account.public_send(config[:emails])

    config[:mailer].negative_sentiment_notification(
      emails: recipients,
      conversation: conversation,
      customer_data: customer_data
    ).deliver_now

    sms_args = { conversation: conversation, emails: recipients, customer_data: customer_data }
    sms_args[:category] = config[:sms_category] if config[:sms_category]
    config[:sms_service].new(**sms_args).perform
  end
end
