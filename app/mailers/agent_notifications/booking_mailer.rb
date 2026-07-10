class AgentNotifications::BookingMailer < ApplicationMailer
  def booking_notification(emails:, conversation:, booking_date:, phone:, email:, whatsapp_number: nil, text_number: nil)
    @conversation = conversation
    @account = conversation.account
    ensure_current_account(@account)

    # Ensure summary is refreshed before sending the email
    begin
      Conversations::SummaryService.new(conversation: @conversation, force_refresh: true).perform
    rescue StandardError
      nil
    end
    @conversation.reload

    # If account is suspended, send to SuperAdmins only
    recipients = if @account.suspended?
                   super_admin_emails(@account)
                 else
                   emails
                 end

    return if recipients.blank?

    @booking_date = booking_date
    @phone = phone
    @customer_email = email
    @whatsapp_number = whatsapp_number
    @text_number = text_number
    @platform_name = @conversation&.inbox&.platform_name
    @instagram_profile_url = instagram_profile_url(@conversation)
    subject = '[Sales] New booking scheduled 📆'

    mail(to: recipients, subject: subject)
  end
end
