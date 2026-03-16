class AgentNotifications::ConversationHandoffMailer < ApplicationMailer
  def notify_handoff(conversation, customer_data = nil)
    return unless smtp_config_set_or_development?

    @account = conversation.account
    @customer_data = customer_data || {}
    ensure_current_account(@account)
    
    # If account is suspended, send to SuperAdmins only
    if @account.suspended?
      recipients = super_admin_emails(@account)
      return if recipients.blank?
    else
      return if @account.agents.blank?
      recipients = @account.agents.pluck(:email)
    end

    @conversation   = conversation
    @action_url     = conversation_url(@conversation)
    @instagram_profile_url = instagram_profile_url(@conversation)

    subject = "[Action required] High-priority conversation requires attention"

    send_mail_with_liquid(
      to: recipients,
      subject: subject
    )
  end

  private

  def liquid_droppables
    super.merge!({
                   conversation: @conversation,
                   inbox: @conversation.inbox,
                   account: @account,
                   instagram_profile_url: @instagram_profile_url
                 })
  end

  def liquid_locals
    super.merge({
                  stark_customer_name: @customer_data['name'],
                  stark_customer_phone: @customer_data['phone'],
                  stark_customer_email: @customer_data['email']
                })
  end
end
