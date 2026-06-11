class Facebook::SendOnFacebookService < Base::SendOnChannelService
  private

  def channel_class
    Channel::FacebookPage
  end

  def perform_reply
    success = true

    if message.content_type == 'cards'
      items = message.content_attributes&.dig('items')
      if items.is_a?(Array) && items.any?
        success = send_message_to_facebook(fb_cards_template_params(items))
      end
    else
      send_message_to_facebook(fb_text_message_params) if message.content.present?

      message.attachments.each do |attachment|
        result = send_message_to_facebook(fb_attachment_message_params(attachment))
        success = false if result == false
      end
    end

    if success
      message.mark_sent!
      enqueue_next_message
    end
  rescue Facebook::Messenger::FacebookError => e
    # TODO : handle specific errors or else page will get disconnected
    handle_facebook_error(e)
    Messages::StatusUpdateService.new(message, 'failed', e.message).perform
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
        quick_replies: message.content_attributes['items'].map do |item|
          {
            content_type: 'text',
            payload: item['title'],
            title: item['title']
          }
        end
      }
    else
      { text: message.outgoing_content }
    end
  end

  def external_error(response)
    # https://developers.facebook.com/docs/graph-api/guides/error-handling/
    error_message = response['error']['message']
    error_code = response['error']['code']

    "#{error_code} - #{error_message}"
  end

  def fb_attachment_message_params(attachment)
    url = attachment.external_url.presence || attachment.download_url
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
    elements = items.first(10).filter_map do |item|
      title = item['title'].presence
      next unless title

      element = { title: title.truncate(80) }
      element[:image_url] = item['media_url'] if item['media_url'].present?
      element[:subtitle] = item['description'].truncate(80) if item['description'].present?

      action = item['actions']&.first
      if action.present?
        element[:buttons] = [{
          type: 'postback',
          title: (action['text'].presence || 'View Details').truncate(20),
          payload: action['payload'].to_s.truncate(1000)
        }]
      end

      element
    end

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
