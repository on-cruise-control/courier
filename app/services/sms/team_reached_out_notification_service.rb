class Sms::TeamReachedOutNotificationService
  def initialize(conversation:, emails:)
    @conversation = conversation
    @account = conversation.account
    @emails = emails
  end

  def perform
    return unless sms_config_enabled?

    recipients = recipients_with_phone_numbers
    return if recipients.blank?

    message_body = build_message_body
    send_sms_to_recipients(recipients, message_body)
  rescue StandardError => e
    Rails.logger.error("Failed to send team reached out SMS notifications: #{e.message}")
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

  def recipients_with_phone_numbers
    User.where(email: @emails).where.not(phone_number: [nil, ''])
  end

  def build_message_body
    account_name = @account.name
    platform_name = @conversation.inbox&.platform_name
    customer_name = @conversation.contact&.name
    conversation_url = Rails.application.routes.url_helpers.app_account_conversation_url(
      account_id: @account.id,
      id: @conversation.display_id,
      host: ENV.fetch('FRONTEND_URL', 'https://courier.getcruisecontrol.com')
    )

    body = <<~SMS
      Follow-Up Required: Team Has Not Reached Out

      Dealership: #{account_name}
      #{"Platform: #{platform_name}(DM)" if platform_name.present?}
      #{"Name: #{customer_name}" if customer_name.present?}

      Our system has detected that the team has not yet reached out to this customer. Please follow up as soon as possible.
    SMS

    summary = @conversation.summary
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
      Rails.logger.error("Failed to send team reached out SMS to #{recipient.name} (#{recipient.phone_number}): #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Unexpected error sending team reached out SMS to #{recipient.name}: #{e.message}")
    end
  end
end
