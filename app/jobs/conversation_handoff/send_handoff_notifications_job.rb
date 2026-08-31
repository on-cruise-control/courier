class ConversationHandoff::SendHandoffNotificationsJob < ApplicationJob
  queue_as :default

  def perform(conversation, customer_data = nil, emails = nil)
    return if conversation.blank?

    begin
      Conversations::SummaryService.new(conversation: conversation, force_refresh: true, skip_rate_limit: true).perform

      if emails.present? || GlobalConfigService.default_emails_present?
        AdministratorNotifications::ConversationHandoffMailer.notify_handoff(conversation, customer_data, to: emails).deliver_later
        Sms::HandoffNotificationService.new(conversation, emails: emails, customer_data: customer_data).perform if emails.present?
      else
        Rails.logger.warn("Vehicle parts email not configured for account #{conversation.account.id}")
      end
    rescue StandardError => e
      Rails.logger.error("Failed to send handoff notifications: #{e.message}")
      SlackNotifierService.new(
        text: "Handoff failed. Failed to send handoff notifications: #{e.message}"
      )
    end
  end
end
