module Stark
  module Validator
    UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    VALID_EVENTS = %w[message.created].freeze

    extend ActiveSupport::Concern

    included do
    end

    def can_process_message?
      valid_event_name? && valid_bot_url? && incoming_message? && !service_hours_active? && unassigned_conversation?
    end

    # GoTo inboxes with synced service hours: agents handle the conversation while the service department is open.
    def service_hours_active?
      goto_channel&.service_hours_active? || false
    end

    # Outside the service windows (GoTo inboxes with synced hours); used to ignore agent replies sent during service hours.
    def after_hours_takeover?
      goto_channel&.service_hours.present? && !service_hours_active?
    end

    def goto_channel
      channel = event_data[:message].conversation.inbox.channel
      channel if channel.is_a?(Channel::GotoSms)
    end

    def valid_event_name?
      VALID_EVENTS.include?(event_name)
    end

    def valid_bot_url?
      agent_bot.outgoing_url.present?
    end

    def incoming_message?
      event_data[:message].incoming?
    end

    def unassigned_conversation?
      event_data[:message].conversation.assignee_id.blank?
    end

    def valid_dealership_id?(dealership_id)
      dealership_id.present? && dealership_id.match?(UUID_REGEX)
    end
  end
end
