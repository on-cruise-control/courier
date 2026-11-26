class Goto::IncomingMessageService
  include ::FileTypeHelper

  pattr_initialize [:channel!, :payload!]

  # GoTo retries webhooks, so the channel row lock keeps concurrent deliveries of one message from creating duplicates.
  def perform
    channel.with_lock do
      next if inbox.messages.exists?(source_id: payload[:messageId])

      @contact, @conversation = Goto::ConversationResolver.new(inbox: inbox, phone_number: phone_number).perform
      next if outgoing? && claim_courier_message

      @message = @conversation.messages.build(message_params)
      attach_files
      @message.save!
    end
  end

  private

  def inbox
    @inbox ||= channel.inbox
  end

  def outgoing?
    payload[:direction] == 'OUTBOUND'
  end

  def phone_number
    outgoing? ? Array(payload[:contactTouchpoints]).first : payload[:authorTouchpoint]
  end

  def message_params
    params = {
      content: payload[:body],
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: outgoing? ? :outgoing : :incoming,
      sender: outgoing? ? nil : @contact,
      source_id: payload[:messageId]
    }
    return params unless outgoing?

    params.merge(status: :delivered, content_attributes: { external_echo: true })
  end

  def claim_courier_message
    message = @conversation.messages.outgoing.where(source_id: nil).where('created_at > ?', 2.minutes.ago)
                           .find_by("COALESCE(content, '') = ?", payload[:body].to_s)
    message&.update!(source_id: payload[:messageId])
  end

  def attach_files
    Array(payload.dig(:attachments, :items)).each do |item|
      file = download_attachment(item[:attachmentId])
      next if file.blank?

      @message.attachments.new(
        account_id: @message.account_id,
        file_type: file_type(file.content_type),
        file: { io: file, filename: item[:name] || file.original_filename, content_type: file.content_type }
      )
    end
  end

  def download_attachment(attachment_id)
    response = Faraday.get("#{Channel::GotoSms::API_URL}/messaging/v2/accounts/#{channel.account_key}/attachments/#{attachment_id}",
                           nil, 'Authorization' => "Bearer #{channel.access_token!}")
    Down.download(response.headers['location']) if response.status == 302
  rescue Down::Error => e
    Rails.logger.error "[GOTO] attachment download failed: #{e.message}"
    nil
  end
end
