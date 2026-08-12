class Messages::Instagram::BaseMessageBuilder < Messages::Messenger::MessageBuilder
  attr_reader :messaging

  def initialize(messaging, inbox, outgoing_echo: false)
    super()
    @messaging = messaging
    @inbox = inbox
    @outgoing_echo = outgoing_echo
  end

  def perform
    return if @inbox.channel.reauthorization_required?

    ActiveRecord::Base.transaction do
      build_message
    end
  rescue StandardError => e
    handle_error(e)
  end

  private

  def attachments
    @messaging[:message][:attachments] || {}
  end

  def message_type
    @outgoing_echo ? :outgoing : :incoming
  end

  def message_identifier
    message[:mid]
  end

  def message_source_id
    @outgoing_echo ? recipient_id : sender_id
  end

  def message_is_unsupported?
    message[:is_unsupported].present? && @messaging[:message][:is_unsupported] == true
  end

  def sender_id
    @messaging[:sender][:id]
  end

  def recipient_id
    @messaging[:recipient][:id]
  end

  def message
    @messaging[:message]
  end

  def contact
    @contact ||= @inbox.contact_inboxes.find_by(source_id: message_source_id)&.contact
  end

  def conversation
    @conversation ||= set_conversation_based_on_inbox_config
  end

  def set_conversation_based_on_inbox_config
    if @inbox.lock_to_single_conversation
      find_conversation_scope.order(created_at: :desc).first || build_conversation
    else
      find_or_build_for_multiple_conversations
    end
  end

  def find_conversation_scope
    Conversation.where(conversation_params)
  end

  def find_or_build_for_multiple_conversations
    last_conversation = find_conversation_scope.where.not(status: :resolved).order(created_at: :desc).first
    return build_conversation if last_conversation.nil?

    last_conversation
  end

  def message_content
    @messaging[:message][:text]
  end

  def story_reply_attributes
    message[:reply_to][:story] if message[:reply_to].present? && message[:reply_to][:story].present?
  end

  def message_reply_attributes
    message[:reply_to][:mid] if message[:reply_to].present? && message[:reply_to][:mid].present?
  end

  def build_message
    # Ensure conversation is resolved first (respects lock_to_single_conversation config)
    existing_conversation = conversation

    # Find or reuse existing instagram_dm conversation for template DMs
    contact_id = contact.id
    inbox_id = @inbox.id
    account_id = @inbox.account_id

    template_dm_conversation = Conversation.where(
      contact_id: contact_id,
      inbox_id: inbox_id,
      account_id: account_id
    ).where("conversations.additional_attributes->>'type' = ?", 'instagram_dm').last

    @conversation = template_dm_conversation || existing_conversation || build_conversation

    # Duplicate webhook events may be sent for the same message
    # when a user is connected to the Instagram account through both Messenger and Instagram login.
    return if message_already_exists?

    return if message_content.blank? && all_unsupported_files?

    @message = @conversation.messages.create!(message_params)
    save_story_id

    # Mark conversation type as instagram_dm
    additional_attributes = @conversation.additional_attributes || {}
    unless additional_attributes['type'] == 'instagram_dm'
      additional_attributes['type'] = 'instagram_dm'
      @conversation.update!(additional_attributes: additional_attributes)
    end

    attachments.each do |attachment|
      process_attachment(attachment)
    end

    ensure_story_mention_content
  end

  def save_story_id
    return if story_reply_attributes.blank?

    @message.save_story_info(story_reply_attributes)
    create_story_reply_attachment(story_reply_attributes['url'])
  end

  def create_story_reply_attachment(story_url)
    return if story_url.blank?

    attachment = @message.attachments.new(
      file_type: :ig_story,
      account_id: @message.account_id,
      external_url: story_url
    )
    attachment.save!
    begin
      attach_file(attachment, story_url)
    rescue Down::Error, StandardError => e
      Rails.logger.warn "Failed to download Instagram story attachment: #{e.message}"
    end
    @message.content_attributes[:image_type] = 'ig_story_reply'
    @message.save!
  end

  def build_conversation
    @contact_inbox ||= contact.contact_inboxes.find_by!(source_id: message_source_id)
    Conversation.create!(conversation_params.merge(
                           contact_inbox_id: @contact_inbox.id,
                           additional_attributes: additional_conversation_attributes
                         ))
  end

  def additional_conversation_attributes
    {}
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: contact.id
    }
  end

  def message_params
    params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: message_type,
      status: @outgoing_echo ? :delivered : :sent,
      source_id: message_identifier,
      content: message_content,
      sender: @outgoing_echo ? nil : contact,
      content_attributes: {
        in_reply_to_external_id: message_reply_attributes
      },
      additional_attributes: { 'delivery_status': 'sent' }
    }

    params[:content_attributes][:external_echo] = true if @outgoing_echo
    params[:content_attributes][:is_unsupported] = true if message_is_unsupported?

    referral = ad_referral_attributes(message || {})
    params[:content_attributes][:referral] = referral if referral.present?

    params
  end

  def message_already_exists?
    return true if find_message_by_source_id(@messaging[:message][:mid]).present?
    return true if @outgoing_echo && recent_duplicate_echo?

    false
  end

  def recent_duplicate_echo?
    content = @messaging.dig(:message, :text)

    if content.present?
      # Text case
      return conversation.messages.outgoing
                         .where(content: content)
                         .where('created_at >= ?', 2.minutes.ago)
                         .exists?
    end

    # Image case

    conversation.messages.outgoing
                .where(source_id: nil)
                .where(content: nil)
                .where('created_at >= ?', 1.minute.ago).exists?
  end

  def find_message_by_source_id(source_id)
    return unless source_id

    @message = Message.find_by(source_id: source_id)
  end

  def all_unsupported_files?
    return if attachments.empty?

    attachments_type = attachments.pluck(:type).uniq.first
    unsupported_file_type?(attachments_type)
  end

  def handle_error(error)
    ChatwootExceptionTracker.new(error, account: @inbox.account).capture_exception
    true
  end

  def ensure_story_mention_content
    return unless @message.present?
    return unless @message.content_attributes[:image_type] == 'story_mention'

    Rails.logger.info(
      "[InstagramStoryMentionFallback] message_id=#{@message.id} content missing. attributes=#{@message.content_attributes}"
    )

    if @message.outgoing?
      reply_content = I18n.t(
        'conversations.messages.instagram_story_reply_content',
        username: story_reply_username
      )
      @message.update!(content: reply_content) unless @message.content == reply_content
    elsif @message.content.blank?
      @message.update!(content: I18n.t('conversations.messages.instagram_story_content', story_sender: story_sender_label))
    end
  end

  def story_reply_username
    contact_name = contact&.additional_attributes&.dig('social_instagram_user_name') ||
                   contact&.additional_attributes&.dig('social_profiles', 'instagram') ||
                   contact&.name ||
                   contact&.identifier
    contact_name.presence || I18n.t('conversations.messages.instagram_story_unknown_sender')
  end

  def story_sender_label
    story_sender_attr = @message.content_attributes[:story_sender]
    raw_sender = story_sender_attr.to_s.strip
    contact_name = contact&.name.presence || contact&.identifier.presence

    if raw_sender.blank? || raw_sender =~ /\A\d+\z/
      contact_name.presence || I18n.t('conversations.messages.instagram_story_unknown_sender')
    else
      raw_sender
    end
  end

  def ensure_story_attachment(story_url)
    return if story_url.blank?
    return if @message.attachments.exists?

    @message.attachments.create!(
      account_id: @message.account_id,
      file_type: :story_mention,
      external_url: story_url
    )
  end

  def process_attachment(attachment)
    super(attachment)
    ensure_story_mention_content if attachment['type'].to_s == 'story_mention'
  end

  # Abstract methods to be implemented by subclasses
  def get_story_object_from_source_id(source_id)
    raise NotImplementedError
  end
end
