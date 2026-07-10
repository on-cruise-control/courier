class Sms::HandoffNotificationService
  def initialize(conversation, emails:, customer_data: nil)
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
    Rails.logger.error("Failed to send handoff SMS notifications: #{e.message}")
  end

  private

  def sms_config_enabled?
    twilio_account_sid.present? &&
      twilio_auth_token.present? &&
      organization_phone_number.present?
  end

  def twilio_account_sid
    @twilio_account_sid ||= GlobalConfig.get_value('TWILIO_ACCOUNT_SID')
  end

  def twilio_auth_token
    @twilio_auth_token ||= GlobalConfig.get_value('TWILIO_AUTH_TOKEN')
  end

  def organization_phone_number
    @organization_phone_number ||= GlobalConfig.get_value('TWILIO_ORGANIZATION_PHONE_NUMBER')
  end

  def conversation_summary
    Conversations::SummaryService.new(conversation: @conversation).perform
    @conversation.summary
  end

  def recipients_with_phone_numbers
    User.where(email: @emails).where.not(phone_number: [nil, ''])
  end

  def build_message_body
    account_name = @account.name
    conversation_url = Rails.application.routes.url_helpers.app_account_conversation_url(
      account_id: @account.id,
      id: @conversation.display_id,
      host: ENV.fetch('FRONTEND_URL', 'https://courier.getcruisecontrol.com')
    )
    platform_name = @conversation.inbox&.platform_name
    customer_name = @customer_data&.dig('name').presence || @conversation.contact&.name

    body = <<~SMS
      🔔 Conversation Vehicle Parts Alert

      Dealership: #{account_name}
      #{"Platform: #{platform_name} (DM)" if platform_name.present?}
      #{"Name: #{customer_name}" if customer_name.present?}


      The customer has requested vehicle parts. Please contact them as soon as possible to verify their requirements and proceed accordingly.
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
      Rails.logger.error("Failed to send SMS to #{recipient.name} (#{recipient.phone_number}): #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Unexpected error sending SMS to #{recipient.name}: #{e.message}")
    end
  end
end
