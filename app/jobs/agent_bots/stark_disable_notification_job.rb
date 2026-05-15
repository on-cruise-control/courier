class AgentBots::StarkDisableNotificationJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, human_message_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    human_message = Message.find_by(id: human_message_id)
    return unless human_message

    # If a newer human outgoing message exists after the trigger, skip —
    # the old cycle is superseded and a new job will be scheduled on the next incoming message.
    newer_human_sent = conversation.messages
                                   .outgoing
                                   .where('created_at > ?', human_message.created_at)
                                   .exists?
    if newer_human_sent
      Rails.logger.info "⏩ [StarkDisableNotif] Skipping — newer human message found (conv #{conversation_id})"
      clear_jid(conversation)
      return
    end

    send_slack_notification(conversation)
    clear_jid(conversation)
  end

  private

  def clear_jid(conversation)
    conversation.additional_attributes.delete('stark_disable_notification_jid')
    conversation.save!
  end

  def send_slack_notification(conversation)
    contact = conversation.contact
    account = conversation.account

    base_url = ENV.fetch('FRONTEND_URL', nil)
    conversation_url = "#{base_url}/app/accounts/#{account.id}/conversations/#{conversation.display_id}"

    message = "🤖 *Stark AI Disabled*\n" \
              "Account: *#{account.name}*\n" \
              "Name: #{contact&.name || 'Unknown'}\n\n" \
              "A human agent replied — Stark is paused for 24 hours.\n" \
              "Stark will resume automatically after 24 hours of no human replies.\n\n" \
              "<#{conversation_url}|View Conversation>"

    SlackNotifierService.call(text: message, channel: ENV['SLACK_STARK_DISABLE_CHANNEL'])
  end
end
