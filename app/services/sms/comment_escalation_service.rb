class Sms::CommentEscalationService
  include Sms::Concerns::TwilioConfigurable

  BANNERS = {
    'sales' => '🚨 Negative Sales Comment Detected',
    'service' => '🚨 Negative Service Comment Detected',
    'parts' => '🚨 Negative Parts Comment Detected'
  }.freeze

  def initialize(conversation:, emails:, category:, customer_data: nil)
    @conversation = conversation
    @account = conversation.account
    @emails = emails
    @category = category
    @customer_data = customer_data
  end

  def perform
    return unless sms_config_enabled?

    recipients = recipients_with_phone_numbers
    return if recipients.blank?

    message_body = build_message_body
    send_sms_to_recipients(recipients, message_body)
  rescue StandardError => e
    Rails.logger.error("Failed to send #{@category} comment escalation SMS notifications: #{e.message}")
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
    platform_name = @conversation.inbox&.platform_name
    customer_name = @customer_data&.dig('name').presence || @conversation.contact&.name
    comment = @conversation.messages.where(message_type: :incoming).last&.content || nil

    conversation_url = Rails.application.routes.url_helpers.app_account_conversation_url(
      account_id: @account.id,
      id: @conversation.display_id,
      host: ENV.fetch('FRONTEND_URL', 'https://courier.getcruisecontrol.com')
    )

    body = <<~SMS
      #{BANNERS.fetch(@category, '🚨 Negative Comment Detected')}

      Dealership: #{account_name}
      #{"Platform: #{platform_name} (comment)" if platform_name.present?}
      #{"Name: #{customer_name}" if customer_name.present?}

      Please address the comment promptly.
    SMS

    summary = conversation_summary
    body += "\nNegative Comment: #{comment}\n" if comment.present?
    body += "\nSummary: #{summary}\n" if summary.present?

    post_url = @conversation.additional_attributes['post_url']
    body += "\nView post: #{post_url}\n" if post_url.present?

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
      Rails.logger.info "✅ #{@category} comment escalation SMS sent to #{recipient.name} (#{recipient.phone_number})"
    rescue Twilio::REST::TwilioError => e
      Rails.logger.error("Failed to send #{@category} comment escalation SMS to #{recipient.name} (#{recipient.phone_number}): #{e.message}")
    rescue StandardError => e
      Rails.logger.error("Unexpected error sending #{@category} comment escalation SMS to #{recipient.name}: #{e.message}")
    end
  end
end
