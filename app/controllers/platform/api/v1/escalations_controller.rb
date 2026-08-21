class Platform::Api::V1::EscalationsController < PlatformController
  def create
    id = params[:conversation_id] || params[:conversation]
    conversation = Conversation.find_by(id: id)
    return render_error('Conversation not found', :not_found) unless conversation

    account = conversation.account
    emails = params[:manager_emails].presence || account.escalation_emails

    if emails.blank? && !GlobalConfigService.default_emails_present?
      render_error('No escalation emails configured', :unprocessable_entity)
      return
    end

    EscalationNotificationJob.perform_later(conversation.id, emails, nil)

    render json: {
      success: true,
      recipients: emails,
      total_sent: emails.size
    }
  end

  private

  def render_error(message, status)
    render json: { success: false, error: message }, status: status
  end
end
