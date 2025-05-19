class ConversationHandoffService
  HANDOFF_COOLDOWN_HOURS = 4

  def initialize(conversation)
    @conversation = conversation
  end

  def process_handoff
    return unless should_send_notification?

    @conversation.update(last_handoff_at: Time.current)
    ConversationHandoff::SendHandoffNotificationsJob.perform_later(@conversation)
  end

  private

  def should_send_notification?
    return true if @conversation.last_handoff_at.nil?

    hours_since_last_handoff = ((Time.current - @conversation.last_handoff_at) / 1.hour).round
    hours_since_last_handoff >= HANDOFF_COOLDOWN_HOURS
  end
end
