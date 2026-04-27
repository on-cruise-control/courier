class Sms::BookingNotificationService
  def initialize(conversation:, booking_date:, phone:, email:, whatsapp_number: nil, text_number: nil)
    @conversation = conversation
    @account = conversation.account
    @booking_date = booking_date
    @customer_phone = phone
    @customer_email = email
    @whatsapp_number = whatsapp_number
    @text_number = text_number
  end

  def perform
    return unless sms_config_enabled?

    recipients = recipients_with_phone_numbers
    return if recipients.blank?

    message_body = build_message_body
    send_sms_to_recipients(recipients, message_body)
  rescue StandardError => e
    Rails.logger.error("Failed to send booking SMS notifications: #{e.message}")
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
    # Get users whose emails are in the booking_emails list and have phone numbers
    emails = @account.booking_emails || []
    User.where(email: emails).where.not(phone_number: [nil, ''])
  end

  def build_message_body
    account_name = @account.name
    conversation_url = Rails.application.routes.url_helpers.app_account_conversation_url(
      account_id: @account.id,
      id: @conversation.display_id,
      host: ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    )

    body = <<~SMS
      📆 New Booking Scheduled

      Dealership: #{account_name}

      Booking Date: #{@booking_date}
      Customer Phone: #{@customer_phone}
      Customer Email: #{@customer_email}
    SMS
    
    body += "      WhatsApp Number: #{@whatsapp_number}\n" if @whatsapp_number.present?
    body += "      Text Number: #{@text_number}\n" if @text_number.present?

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
      Rails.logger.error("Failed to send booking SMS to #{recipient.name} (#{recipient.phone_number}): #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Unexpected error sending booking SMS to #{recipient.name}: #{e.message}")
    end
  end
end
