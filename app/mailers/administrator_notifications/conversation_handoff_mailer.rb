class AdministratorNotifications::ConversationHandoffMailer < AdministratorNotifications::BaseMailer
  def notify_handoff(conversation, customer_data = nil)
    return unless smtp_config_set_or_development?

    @conversation   = conversation
    @account        = conversation.account
    @action_url     = conversation_url(@conversation)
    @instagram_profile_url = instagram_profile_url(@conversation)
    @customer_data = customer_data || {}
    ensure_current_account(@account)

    subject = "[Action required] High-priority conversation requires attention"

    # If account is suspended, send to SuperAdmins only (handled in send_notification)
    send_notification(
      subject,
      to: @account.suspended? ? super_admin_emails(@account) : admin_emails,
      action_url: @action_url,
      meta: {
        conversation_id: @conversation.display_id,
        inbox: @conversation.inbox.name
      }
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
