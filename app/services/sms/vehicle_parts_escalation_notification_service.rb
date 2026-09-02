class Sms::VehiclePartsEscalationNotificationService
  include Sms::Concerns::TwilioConfigurable

  def initialize(conversation:, emails:, customer_data: nil)
    @conversation = conversation
    @account = conversation.account
    @emails = emails
    @customer_data = customer_data
  end

  def perform
    return unless sms_config_enabled?

    recipients = recipients_with_phone_numbers
    return if recipients.blank?

    message_body = build_message_body
    send_sms_to_recipients(recipients, message_body)
  rescue StandardError => e
    Rails.logger.error("Failed to send vehicle parts escalation SMS notifications: #{e.message}")
  end

  private

  def conversation_summary
    Conversations::SummaryService.new(conversation: @conversation).perform
    @conversation.summary
  end

  def recipients_with_phone_numbers
    User.where(email: @emails).where.not(phone_number: [nil, ''])
  end

  def build_message_body
    account_name = @account.name
    inbox = @conversation.inbox
    platform_name = inbox&.platform_name
    customer_name = @customer_data&.dig('name').presence || @conversation.contact&.name
    conversation_url = Rails.application.routes.url_helpers.app_account_conversation_url(
      account_id: @account.id,
      id: @conversation.display_id,
      host: ENV.fetch('FRONTEND_URL', 'https://courier.getcruisecontrol.com')
    )

    body = <<~SMS
      🚨 Urgent Vehicle Parts Escalation Required

      Dealership: #{account_name}
      #{"Platform: #{platform_name}#{' (DM)' if inbox&.dm_channel?}" if platform_name.present?}
      #{"Name: #{customer_name}" if customer_name.present?}

      A parts-related customer complaint. Please take over this conversation manually.
    SMS

    summary = conversation_summary
    body += "\nSummary: #{summary}\n" if summary.present?

    body += "\nView conversation: #{conversation_url}\n"

    body.strip
  end

  def send_sms_to_recipients(recipients, message_body)
    twilio_client = Twilio::REST::Client.new(twilio_account_sid, twilio_auth_token)

    recipients.each do |recipient|
      twilio_client.messages.create(
        from: organization_phone_number,
        to: recipient.phone_number,
        body: message_body
      )
    rescue Twilio::REST::TwilioError => e
      Rails.logger.error("Failed to send vehicle parts escalation SMS to #{recipient.name} (#{recipient.phone_number}): #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Unexpected error sending vehicle parts escalation SMS to #{recipient.name}: #{e.message}")
    end
  end
end
