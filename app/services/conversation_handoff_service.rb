class ConversationHandoffService
  HANDOFF_COOLDOWN_MINUTES = 240 # 4 hours in minutes
  HANDOFF_LABEL = 'handoff'
  ESCALATION_LABEL = 'escalation'

  def initialize(conversation)
    @conversation = conversation
  end

  def process_handoff(customer_data = nil, handoff_reason = nil , message = nil)
    return unless should_send_notification?

    label = label_for_reason(handoff_reason)
    return unless label
    ensure_label_exists(label)
    update_handoff_state(label)
    schedule_label_change

    case handoff_reason

    when 'external_escalation'
     if @conversation.account.escalation_emails.present?
        EscalationNotificationJob.perform_later(@conversation.id, @conversation.account.escalation_emails, customer_data , message)
      else
        Rails.logger.warn("Escalation email not configured for account #{@conversation.account.id}")
      end
    when 'vehicle_parts'
      if @conversation.account.vehicle_parts_emails.present?
        ConversationHandoff::SendHandoffNotificationsJob.perform_later(@conversation, customer_data, @conversation.account.vehicle_parts_emails)
      else
        Rails.logger.warn("Vehicle parts email not configured for account #{@conversation.account.id}")
      end
    end
  end

  private

 def label_for_reason(handoff_reason)

   case handoff_reason
  when 'external_escalation'
    ESCALATION_LABEL
  when 'vehicle_parts'
    HANDOFF_LABEL
  else
    nil
  end
end

  def should_send_notification?
    return true if @conversation.last_handoff_at.nil?

    minutes_since_last_handoff = ((Time.current - @conversation.last_handoff_at) / 1.minute).round
    minutes_since_last_handoff >= HANDOFF_COOLDOWN_MINUTES
  end

  def ensure_label_exists(label_title)
    color = label_title == ESCALATION_LABEL ? '#FF0000' : '#1f93ff'
    Label.find_or_create_by!(account: @conversation.account, title: label_title) do |label|
      label.show_on_sidebar = true
      label.color = color
    end
  end

  def update_handoff_state(label)
    @conversation.add_labels([label]) unless @conversation.label_list.include?(label)
    @conversation.update_columns(
      last_handoff_at: Time.current,
      handoff_attended_at: nil,
      handoff_attended_by_id: nil
    ) # rubocop:disable Rails/SkipsModelValidations
  end

  def schedule_label_change
    ScheduleHandoffLabelChangeJob.set(wait: HANDOFF_COOLDOWN_MINUTES.minutes)
                                 .perform_later(@conversation)
  end
end
