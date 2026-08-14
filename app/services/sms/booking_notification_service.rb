class Sms::BookingNotificationService
  include Sms::Concerns::TwilioConfigurable

  def initialize(conversation:, booking_date:, phone:, email:, whatsapp_number: nil, text_number: nil, summary: nil,
                 source: nil, campaign: nil, search_term: nil, content_variant: nil, ad_title: nil)
    @conversation = conversation
    @account = conversation.account
    @booking_date = booking_date
    @customer_phone = phone
    @customer_email = email
    @whatsapp_number = whatsapp_number
    @text_number = text_number
    @summary_override = summary
    @source = source
    @campaign = campaign
    @search_term = search_term
    @content_variant = content_variant
    @ad_title = ad_title
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

  def conversation_summary
    return @summary_override if @summary_override.present?

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
    inbox = @conversation.inbox
    platform_name = inbox&.platform_name
    customer_name = @conversation.contact&.name

    body = <<~SMS
      📆 New Booking Scheduled

      Dealership: #{account_name}
      #{"Platform: #{platform_name}#{'(DM)' if inbox&.dm_channel?}" if platform_name.present?}
      #{"Name: #{customer_name}" if customer_name.present?}

      Booking Date: #{@booking_date}
      Customer Phone: #{PhoneNumberFormatter.format(@customer_phone)}
      Customer Email: #{@customer_email}
    SMS

    body += "      WhatsApp Number: #{PhoneNumberFormatter.format(@whatsapp_number)}\n" if @whatsapp_number.present?
    body += "      Text Number: #{PhoneNumberFormatter.format(@text_number)}\n" if @text_number.present?

    body += source_details_section

    summary = conversation_summary
    body += "\nSummary: #{summary}\n" if summary.present?

    body += "\nView conversation: #{conversation_url}\n"

    body.strip
  end

  def source_details_section
    is_website_lead = @source.present? || @campaign.present? || @search_term.present? || @content_variant.present?
    return '' unless is_website_lead || @ad_title.present?

    lines = if is_website_lead
              [
                ("Came From (Source): #{@source}" if @source.present?),
                ("Campaign: #{@campaign}" if @campaign.present?),
                ("Search Term: #{@search_term}" if @search_term.present?),
                ("Ad/Content Variant: #{@content_variant}" if @content_variant.present?)
              ]
            else
              ["Ad Title: #{@ad_title}"]
            end.compact

    "\nSource Details\n#{lines.join("\n")}\n"
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
