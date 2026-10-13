class Instagram::SendOnInstagramService < Base::SendOnChannelService
  include HTTParty

  pattr_initialize [:message!]

  base_uri 'https://graph.facebook.com/v18.0'

  private

  def channel_class
    Channel::Instagram
  end

  def perform_reply
    if send_reply_for_content_type
      message.mark_sent!
      enqueue_next_message
    end
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account, user: message.sender).capture_exception
  end

  def send_reply_for_content_type
    case message.content_type
    when 'cards' then send_cards_reply
    when 'call_to_action' then send_call_to_action_reply
    else send_default_reply
    end
  end

  def send_cards_reply
    items = message.content_attributes&.dig('items')
    return true unless items.is_a?(Array) && items.any?

    send_to_instagram_page(ig_cards_template_params(items))
  end

  def send_call_to_action_reply
    item = message.content_attributes&.dig('items')&.first
    return true if item.blank?

    send_to_instagram_page(ig_button_template_params(item))
  end

  def send_default_reply
    success = true
    success = send_to_instagram_page(message_params) if message.content.present?

    message.attachments.each do |attachment|
      result = send_to_instagram_page(attachment_message_params(attachment))
      success = false if result == false
    end

    success
  end

  def message_params
    {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: ig_text_message_payload
    }.tap { |params| merge_human_agent_tag(params) }
  end

  def ig_text_message_payload
    if message.content_type == 'input_select' && message.content_attributes['items'].any?
      {
        text: message.content,
        quick_replies: message.content_attributes['items'].first(13).map { |item| ig_quick_reply(item) }
      }
    else
      { text: message.content }
    end
  end

  def ig_quick_reply(item)
    {
      content_type: item['content_type'].presence || 'text',
      title: item['title'].to_s.truncate(20),
      payload: (item['value'].presence || item['title']).to_s
    }
  end

  def ig_cards_template_params(items)
    elements = items.first(10).filter_map { |item| ig_card_element(item) }

    {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: 'template',
          payload: {
            template_type: 'generic',
            elements: elements
          }
        }
      }
    }.tap { |params| merge_human_agent_tag(params) }
  end

  def ig_card_element(item)
    title = item['title'].presence
    return unless title

    element = { title: title.truncate(80) }
    element[:image_url] = item['media_url'] if item['media_url'].present?
    element[:subtitle] = item['description'].truncate(80) if item['description'].present?

    buttons = item['actions'].to_a.first(3).filter_map { |action| ig_template_button(action) }
    element[:buttons] = buttons if buttons.any?
    element[:default_action] = ig_default_action(item) if ig_default_action(item)

    element
  end

  def ig_default_action(item)
    url = item['default_action']&.[]('url')
    { type: 'web_url', url: url } if url.present?
  end

  def ig_button_template_params(item)
    buttons = item['buttons'].to_a.first(3).filter_map { |button| ig_template_button(button) }

    {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: 'template',
          payload: {
            template_type: 'button',
            text: item['text'].to_s.truncate(640),
            buttons: buttons
          }
        }
      }
    }.tap { |params| merge_human_agent_tag(params) }
  end

  def ig_template_button(button)
    return if button.blank?

    title = (button['title'].presence || button['text'].presence || 'View Details').truncate(20)
    if button['type'] == 'web_url'
      { type: 'web_url', title: title, url: button['uri'].to_s }
    else
      { type: 'postback', title: title, payload: (button['payload'] || button['uri']).to_s.truncate(1000) }
    end
  end

  def attachment_message_params(attachment)
    # Prefer locally stored file URL over external CDN URL, which may have expired
    url = attachment.file.attached? ? attachment.download_url : (attachment.external_url.presence || attachment.download_url)
    {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: attachment_type(attachment),
          payload: {
            url: url
          }
        }
      }
    }.tap { |params| merge_human_agent_tag(params) }
  end

  def send_to_instagram_page(message_content)
    access_token = channel.access_token
    query = { access_token: access_token }

    if conversation.additional_attributes['type'] == 'instagram_comments'

      send_reply_to_instagram_comment(query, message_content)
    else
      send_message_to_instagram(query, message_content)
    end
  end

  def send_reply_to_instagram_comment(query, message_content)
    comment_id = conversation.additional_attributes['comment_id']
    url = "https://graph.instagram.com/v23.0/#{comment_id}/replies"

    response = HTTParty.post(
      url,
      body: {
        message: message_content[:message][:text],
        access_token: query[:access_token]
      }
    )
    handle_response(response)
  end

  def send_message_to_instagram(query, message_content)
    url = 'https://graph.instagram.com/v23.0/me/messages'
    response = HTTParty.post(
      url,
      body: message_content.to_json,
      headers: { 'Content-Type' => 'application/json' },
      query: query
    )

    handle_response(response)
  end

  def handle_response(response)
    if response['error'].present?
      friendly_message = external_error(response)
      Messages::StatusUpdateService.new(message, 'failed', friendly_message).perform
      Rails.logger.error("Instagram response: #{response['error']} : #{message.content}")
      message.mark_failed!(friendly_message)
      false
    else
      source_id = response['id'] || response['message_id']
      message.update!(source_id: source_id) if source_id.present?
      true
    end
  end

  def enqueue_next_message
    next_msg = conversation.messages
                           .where('id > ?', message.id)
                           .where("additional_attributes ->> 'delivery_status' = ?", 'pending')
                           .order(:id)
                           .first

    return unless next_msg.present?

    SendReplyJob.perform_later(next_msg.id)
  end

  def external_error(response)
    # https://developers.facebook.com/docs/graph-api/guides/error-handling/
    error_message = response['error']['message']
    error_code = response['error']['code']
    error_subcode = response['error']['error_subcode']
    raw = "#{error_code} - #{error_message}"

    friendly_message_for_instagram_error(raw, error_code: error_code, error_subcode: error_subcode)
  end

  def friendly_message_for_instagram_error(raw_message, error_code: nil, error_subcode: nil)
    # Prioritize subcode if available as it is more specific
    code = error_subcode || error_code || extract_instagram_error_code(raw_message)
    return raw_message if code.blank?

    I18n.t("inbox.instagram_errors.#{code}", default: raw_message)
  end

  def extract_instagram_error_code(message)
    return nil if message.blank?

    m = message.match(/\A(?:\(#)?(\d+)\)?\s*-?\s*/)
    m[1] if m
  end

  def merge_human_agent_tag(params)
    global_config = GlobalConfig.get('ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT')
    return params unless global_config['ENABLE_INSTAGRAM_CHANNEL_HUMAN_AGENT']

    params[:messaging_type] = 'MESSAGE_TAG'
    params[:tag] = 'HUMAN_AGENT'
    params
  end

  def attachment_type(attachment)
    return attachment.file_type if %w[image audio video file].include?(attachment.file_type)

    'file'
  end

  def contact
    @contact ||= begin
      conv = message.conversation
      raise "❌ Conversation not found for message ID #{message.id}" unless conv
      raise "❌ Contact not found for conversation ID #{conv.id}" unless conv.contact

      conv.contact
    end
  end

  def inbox
    @inbox ||= begin
      raise "❌ Inbox not found for message ID #{message.id}" unless message.inbox

      message.inbox
    end
  end

  def channel
    @channel ||= inbox.channel
  end

  def conversation
    @conversation ||= begin
      raise "❌ Conversation not found for message ID #{message.id}" unless message.conversation

      message.conversation
    end
  end
end
