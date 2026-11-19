class Goto::IncomingMessageService
  include ::FileTypeHelper

  pattr_initialize [:channel!, :payload!]

  # GoTo retries webhooks, so the channel row lock keeps concurrent deliveries of one message from creating duplicates.
  def perform
    channel.with_lock do
      next if inbox.messages.exists?(source_id: payload[:messageId])

      set_contact
      set_conversation
      @message = @conversation.messages.build(
        content: payload[:body],
        account_id: inbox.account_id,
        inbox_id: inbox.id,
        message_type: :incoming,
        sender: @contact,
        source_id: payload[:messageId]
      )
      attach_files
      @message.save!
    end
  end

  private

  def inbox
    @inbox ||= channel.inbox
  end

  def phone_number
    payload[:authorTouchpoint]
  end

  def set_contact
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number,
      inbox: inbox,
      contact_attributes: { name: TelephoneNumber.parse(phone_number).international_number, phone_number: phone_number }
    ).perform
    @contact = @contact_inbox.contact
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(account_id: inbox.account_id, inbox_id: inbox.id, contact_id: @contact.id,
                                           contact_inbox_id: @contact_inbox.id)
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
