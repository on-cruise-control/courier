class Facebook::SendOnFacebookService < Base::SendOnChannelService
  private

  def channel_class
    Channel::FacebookPage
  end

  def perform_reply
    if send_reply_for_content_type
      message.mark_sent!
      enqueue_next_message
    end
  rescue Facebook::Messenger::FacebookError => e
    # TODO : handle specific errors or else page will get disconnected
    handle_facebook_error(e)
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
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

    send_message_to_facebook(fb_cards_template_params(items))
  end

  def send_call_to_action_reply
    item = message.content_attributes&.dig('items')&.first
    return true if item.blank?

    send_message_to_facebook(fb_button_template_params(item))
  end

  def send_default_reply
    success = true
    send_message_to_facebook(fb_text_message_params) if message.content.present?

    message.attachments.each do |attachment|
      result = send_message_to_facebook(fb_attachment_message_params(attachment))
      success = false if result == false
    end

    success
  end

  def send_message_to_facebook(delivery_params)
    parsed_result = deliver_message(delivery_params)
    return false if parsed_result.nil?

    if parsed_result['error'].present?
      Messages::StatusUpdateService.new(message, 'failed', external_error(parsed_result)).perform
      Rails.logger.info "Facebook::SendOnFacebookService: Error sending message to Facebook : Page - #{channel.page_id} : #{parsed_result}"
      return false
    end

    message.update!(source_id: parsed_result['message_id']) if parsed_result['message_id'].present?
    true
  end

  def deliver_message(delivery_params)
    result = Facebook::Messenger::Bot.deliver(delivery_params, page_id: channel.page_id)
    JSON.parse(result)
  rescue JSON::ParserError
    Messages::StatusUpdateService.new(message, 'failed', 'Facebook was unable to process this request').perform
    Rails.logger.error "Facebook::SendOnFacebookService: Error parsing JSON response from Facebook : Page - #{channel.page_id} : #{result}"
    nil
  rescue Net::OpenTimeout
    Messages::StatusUpdateService.new(message, 'failed', 'Request timed out, please try again later').perform
    Rails.logger.error "Facebook::SendOnFacebookService: Timeout error sending message to Facebook : Page - #{channel.page_id}"
    nil
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

  def fb_text_message_params
    params = {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: fb_text_message_payload
    }

    merge_human_agent_tag(params)
  end

  def fb_text_message_payload
    if message.content_type == 'input_select' && message.content_attributes['items'].any?
      {
        text: message.content,
        quick_replies: message.content_attributes['items'].first(13).map { |item| fb_quick_reply(item) }
      }
    else
      { text: message.outgoing_content }
    end
  end

  def fb_quick_reply(item)
    {
      content_type: item['content_type'].presence || 'text',
      title: item['title'].to_s.truncate(20),
      payload: (item['value'].presence || item['title']).to_s
    }
  end

  def external_error(response)
    # https://developers.facebook.com/docs/graph-api/guides/error-handling/
    error_message = response['error']['message']
    error_code = response['error']['code']

    "#{error_code} - #{error_message}"
  end

  def fb_attachment_message_params(attachment)
    # Prefer locally stored file URL over external CDN URL, which may have expired
    url = attachment.file.attached? ? attachment.download_url : (attachment.external_url.presence || attachment.download_url)
    params = {
      recipient: { id: contact.get_source_id(inbox.id) },
      message: {
        attachment: {
          type: attachment_type(attachment),
          payload: {
            url: url
          }
        }
      }
    }

    merge_human_agent_tag(params)
  end

  def fb_cards_template_params(items)
    elements = items.first(10).filter_map { |item| fb_card_element(item) }

    params = {
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
    }

    merge_human_agent_tag(params)
  end

  def fb_card_element(item)
    title = item['title'].presence
    return unless title

    element = { title: title.truncate(80) }
    element[:image_url] = item['media_url'] if item['media_url'].present?
    element[:subtitle] = item['description'].truncate(80) if item['description'].present?

    buttons = item['actions'].to_a.first(3).filter_map { |action| fb_template_button(action) }
    element[:buttons] = buttons if buttons.any?
    element[:default_action] = fb_default_action(item) if fb_default_action(item)

    element
  end

  def fb_default_action(item)
    url = item['default_action']&.[]('url')
    { type: 'web_url', url: url } if url.present?
  end

  def fb_button_template_params(item)
    buttons = item['buttons'].to_a.first(3).filter_map { |button| fb_template_button(button) }

    params = {
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
    }

    merge_human_agent_tag(params)
  end

  def fb_template_button(button)
    return if button.blank?

    title = (button['title'].presence || button['text'].presence || 'View Details').truncate(20)
    if button['type'] == 'web_url'
      { type: 'web_url', title: title, url: button['uri'].to_s }
    else
      { type: 'postback', title: title, payload: (button['payload'] || button['uri']).to_s.truncate(1000) }
    end
  end

  def merge_human_agent_tag(params)
    unless GlobalConfigService.load('ENABLE_MESSENGER_CHANNEL_HUMAN_AGENT', nil)
      params[:messaging_type] = 'RESPONSE'
      return params
    end

    params[:messaging_type] = 'MESSAGE_TAG'
    params[:tag] = 'HUMAN_AGENT'
    params
  end

  def attachment_type(attachment)
    return attachment.file_type if %w[image audio video file].include? attachment.file_type

    'file'
  end

  def handle_facebook_error(exception)
    # Refer: https://github.com/jgorset/facebook-messenger/blob/64fe1f5cef4c1e3fca295b205037f64dfebdbcab/lib/facebook/messenger/error.rb
    return unless exception.to_s.include?('The session has been invalidated') || exception.to_s.include?('Error validating access token')

    channel.authorization_error!
  end
end
