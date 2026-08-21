class ConversationHandoff::SendServiceNotificationsJob < ApplicationJob
  queue_as :default

  def perform(conversation, customer_data = nil, emails = nil)
    return if conversation.blank?

    begin
      Conversations::SummaryService.new(conversation: conversation, force_refresh: true, skip_rate_limit: true).perform

      if emails.present? || GlobalConfigService.default_emails_present?
        AdministratorNotifications::ConversationServiceMailer.notify_service(conversation, customer_data, to: emails).deliver_later
        Sms::ServiceNotificationService.new(conversation, emails: emails, customer_data: customer_data).perform if emails.present?
      else
        Rails.logger.warn("Service email not configured for account #{conversation.account.id}")
      end
    rescue StandardError => e
      Rails.logger.error("Failed to send service notifications: #{e.message}")
      SlackNotifierService.new(
        text: "Service notification failed. Failed to send service notifications: #{e.message}"
      )
    end
  end
end
