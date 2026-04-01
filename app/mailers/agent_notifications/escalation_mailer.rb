class AgentNotifications::EscalationMailer < ApplicationMailer
  def escalation_notification(emails:, conversation:)
    @conversation = conversation
    @account = conversation.account
    ensure_current_account(@account)
    
    # If account is suspended, send to SuperAdmins only
    recipients = if @account.suspended?
                   super_admin_emails(@account)
                 else
                   emails
                 end
    
    return if recipients.blank?

    @summary = @conversation.summary
    @customer_name = @conversation.contact.name || 'N/A'
    @platform_name = @conversation.inbox.platform_name
    @action_url = conversation_url(@conversation)
    
    subject = '🚨 Urgent Escalation: Customer Experience Issue – Immediate Attention Required'

    mail(to: recipients, subject: subject)
  end

  private

  def conversation_url(conversation)
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{conversation.account_id}/inbox/#{conversation.inbox_id}/conversations/#{conversation.display_id}"
  end
end
