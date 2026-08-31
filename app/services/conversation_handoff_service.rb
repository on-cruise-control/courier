class ConversationHandoffService
  HANDOFF_COOLDOWN_MINUTES = 240 # 4 hours in minutes
  HANDOFF_LABEL = 'handoff'.freeze
  HANDOFF_LABEL_COLOR = '#1f93ff'.freeze
  VALID_HANDOFF_REASONS = %w[sales_escalation service_escalation vehicle_parts_escalation vehicle_parts service_inquiry].freeze

  AREA_ESCALATIONS = {
    'sales_escalation' => { emails: :sales_escalation_emails, job: 'SalesEscalationNotificationJob',
                            label: 'sales_escalation', color: '#F97316' },
    'service_escalation' => { emails: :service_escalation_emails, job: 'ServiceEscalationNotificationJob',
                              label: 'service_escalation', color: '#A855F7' },
    'vehicle_parts_escalation' => { emails: :vehicle_parts_escalation_emails, job: 'VehiclePartsEscalationNotificationJob',
                                    label: 'vehicle_parts_escalation', color: '#0D9488' }
  }.freeze

  def initialize(conversation)
    @conversation = conversation
  end

  def process_handoff(customer_data = nil, handoff_reason = nil, message = nil)
    return unless should_send_notification?
    return unless VALID_HANDOFF_REASONS.include?(handoff_reason)

    label = label_for_reason(handoff_reason)
    if label
      ensure_label_exists(label)
      update_handoff_state(label)
      schedule_label_change
    end

    if AREA_ESCALATIONS.key?(handoff_reason)
      enqueue_area_escalation(handoff_reason, customer_data, message)
      return
    end

    case handoff_reason

    when 'vehicle_parts'
      if @conversation.account.vehicle_parts_emails.present? || GlobalConfigService.default_emails_present?
        ConversationHandoff::SendHandoffNotificationsJob.perform_later(@conversation, customer_data, @conversation.account.vehicle_parts_emails)
      else
        Rails.logger.warn("Vehicle parts email not configured for account #{@conversation.account.id}")
      end
    when 'service_inquiry'
      if @conversation.account.service_emails.present? || GlobalConfigService.default_emails_present?
        ConversationHandoff::SendServiceNotificationsJob.perform_later(@conversation, customer_data, @conversation.account.service_emails)
      else
        Rails.logger.warn("Service email not configured for account #{@conversation.account.id}")
      end
    end
  end

  private

  def label_for_reason(handoff_reason)
    return AREA_ESCALATIONS[handoff_reason][:label] if AREA_ESCALATIONS.key?(handoff_reason)

    HANDOFF_LABEL if handoff_reason == 'vehicle_parts'
  end

  def enqueue_area_escalation(handoff_reason, customer_data, message)
    config = AREA_ESCALATIONS[handoff_reason]
    emails = @conversation.account.public_send(config[:emails])

    unless emails.present? || GlobalConfigService.default_emails_present?
      Rails.logger.warn("#{handoff_reason} email not configured for account #{@conversation.account.id}")
      return
    end

    config[:job].constantize.perform_later(@conversation.id, emails, customer_data, message)
  end

  def should_send_notification?
    return true if @conversation.last_handoff_at.nil?

    minutes_since_last_handoff = ((Time.current - @conversation.last_handoff_at) / 1.minute).round
    minutes_since_last_handoff >= HANDOFF_COOLDOWN_MINUTES
  end

  def ensure_label_exists(label_title)
    Label.find_or_create_by!(account: @conversation.account, title: label_title) do |label|
      label.show_on_sidebar = true
      label.color = color_for_label(label_title)
    end
  end

  def color_for_label(label_title)
    area = AREA_ESCALATIONS.values.find { |config| config[:label] == label_title }
    area ? area[:color] : HANDOFF_LABEL_COLOR
  end

  def update_handoff_state(label)
    @conversation.add_labels([label]) unless @conversation.label_list.include?(label)
    @conversation.update_columns(
      last_handoff_at: Time.current,
      handoff_attended_at: nil,
      handoff_attended_by_id: nil
    )
  end

  def schedule_label_change
    ScheduleHandoffLabelChangeJob.set(wait: HANDOFF_COOLDOWN_MINUTES.minutes)
                                 .perform_later(@conversation)
  end
end
