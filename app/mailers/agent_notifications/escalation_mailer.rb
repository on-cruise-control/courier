class AgentNotifications::EscalationMailer < ApplicationMailer
  def escalation_notification(emails:, conversation:, customer_data: nil, message: nil)
    @conversation = conversation
    @account = conversation.account
    @dealership_name = conversation.account.name
    @customer_data = customer_data || {}
    @last_incoming_message = message
    ensure_current_account(@account)

    # If account is suspended, send to SuperAdmins only
    recipients = if @account.suspended?
                   super_admin_emails(@account)
                 else
                   emails
                 end

    return if recipients.blank?

    @summary = @conversation.summary
    @customer_name = @customer_data['name'].presence || @conversation.contact.name
    @customer_email = @customer_data['email'].presence
    @customer_phone = @customer_data['phone'].presence
    @platform_name = @conversation.inbox.platform_name
    @action_url = conversation_url(@conversation)

    subject = '[Escalation] 🚨 Urgent Escalation: Customer Experience Issue – Immediate Attention Required'

    mail(to: recipients, subject: subject)
  end

  def negative_sentiment_notification(emails:, conversation:, customer_data: nil)
    @conversation = conversation
    @account = conversation.account
    @dealership_name = conversation.account.name

    # either or the message
    @comment_body = @conversation.messages.where(message_type: :incoming).last || ''
    @comment = @comment_body.content || ''

    ensure_current_account(@account)

    # If account is suspended, send to SuperAdmins only
    recipients = if @account.suspended?
                   super_admin_emails(@account)
                 else
                   emails
                 end

    return if recipients.blank?

    @summary = @conversation.summary
    @customer_name = @conversation.contact.name
    @customer_email = @conversation.contact.email
    @customer_phone = @conversation.contact.phone_number
    @platform_name = @conversation.inbox.platform_name
    @action_url = conversation_url(@conversation)

    subject = '[Escalation] Negative Comment Detected – High-Priority Follow-Up Required'

    mail(to: recipients, subject: subject)
  end

  private

  def conversation_url(conversation)
    "#{ENV.fetch('FRONTEND_URL',
                 nil)}/app/accounts/#{conversation.account_id}/inbox/#{conversation.inbox_id}/conversations/#{conversation.display_id}"
  end
end
