class Goto::SendOnGotoService < Base::SendOnChannelService
  private

  def channel_class
    Channel::GotoSms
  end

  def perform_reply
    message_id = channel.send_message(to: contact_inbox.source_id, body: message.outgoing_content, attachments: message.attachments)
    message.update!(source_id: message_id)
  rescue StandardError => e
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
  end
end
