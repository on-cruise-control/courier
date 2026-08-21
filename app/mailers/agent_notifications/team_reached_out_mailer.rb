class AgentNotifications::TeamReachedOutMailer < ApplicationMailer
  def follow_up_required(emails:, conversation:)
    @conversation = conversation
    @account = conversation.account
    ensure_current_account(@account)

    recipients = if @account.suspended?
                   super_admin_emails(@account)
                 else
                   emails
                 end

    return if recipients.blank? && default_bcc_emails.blank?

    contact = @conversation.contact
    @summary = @conversation.summary
    @customer_name = contact&.name.presence
    @customer_email = contact&.email.presence
    @customer_phone = PhoneNumberFormatter.format(contact&.phone_number.presence)
    @platform_name = @conversation.inbox.platform_name
    @action_url = conversation_url(@conversation)

    mail(to: recipients, subject: '⚠️ Follow-Up Required: Team Has Not Reached Out to Customer', bcc: default_bcc_emails.presence)
  end

  private

  def conversation_url(conversation)
    "#{ENV.fetch('FRONTEND_URL',
                 nil)}/app/accounts/#{conversation.account_id}/inbox/#{conversation.inbox_id}/conversations/#{conversation.display_id}"
  end
end
