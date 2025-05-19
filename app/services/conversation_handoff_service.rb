class ConversationHandoffService
  HANDOFF_COOLDOWN_HOURS = 4
  HANDOFF_LABELS = %w[handoff human].freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def process_handoff
    return unless should_send_notification?

    update_handoff_state
    schedule_label_change

    ConversationHandoff::SendHandoffNotificationsJob.perform_later(@conversation)
  end

  private

  def should_send_notification?
    return true if @conversation.last_handoff_at.nil?

    hours_since_last_handoff = ((Time.current - @conversation.last_handoff_at) / 1.hour).round
    hours_since_last_handoff >= HANDOFF_COOLDOWN_HOURS
  end

  def update_handoff_state
    @conversation.label_list.remove('stark')

    # Find which handoff label to use (use existing or first available)
    current_label = @conversation.labels.find { |label| HANDOFF_LABELS.include?(label.name) }&.name
    available_label = current_label || HANDOFF_LABELS.first

    @conversation.label_list.add(available_label)
    @conversation.last_handoff_at = Time.current
    @conversation.save!
  end

  def schedule_label_change
    # Schedule the job to run in exactly 4 hours
    ScheduleHandoffLabelChangeJob.set(wait: HANDOFF_COOLDOWN_HOURS.hours)
                                 .perform_later(@conversation)
  end
end
