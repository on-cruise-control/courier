module Stark
  module ApiHandler
    extend ActiveSupport::Concern

    included do
      AUTH_TOKEN = ENV.fetch('STARK_API_KEY', nil)
      include HTTParty
      include StarkRetryable
    end

    def get_stark_response(conversation, content, message = nil)
      return nil unless valid_dealership_id?(conversation.account&.dealership_id)

      with_stark_retry(conversation) do
        response = make_api_request(conversation, content, message)

        return nil if response.nil?

        status_code = response.dig('metadata', 'status_code').to_i

        case status_code
        when 200
          parse_stark_response(response , message)
        when 400, 500
          log_stark_error(status_code, response, conversation)
          nil
        else
          log_and_notify_slack(
            Stark::SlackMessageFormatter.format_unexpected_response(response, conversation)
          )
          nil
        end
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Stark response: #{e.message}")
      nil
    rescue StandardError => e
      log_and_notify_slack(
        Stark::SlackMessageFormatter.format_general_error(e, conversation)
      )
      nil
    end

    private

    def make_api_request(conversation, content, message = nil)
      response = HTTParty.post(
        agent_bot.outgoing_url,
        body: build_request_payload(conversation, content, message).to_json,
        headers: build_request_headers,
        timeout: 60
      )

      parse_response_body(response)
    end

    def parse_response_body(response)
      return nil unless response&.body

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Stark response: #{e.message}")
      Rails.logger.error("Response body: #{response.body}")
      raise StandardError, 'Invalid response format from Stark server'
    end

    def build_request_payload(conversation, content, message = nil)
      payload = {
        question: content,
        is_image_attached: message_has_image?(message),
        is_story_mentioned: is_story_mentioned?(message),
        session_id: conversation.id,
        dealership_id: conversation.account&.dealership_id,
        account_id: conversation.account_id,
        customer_id: conversation.contact&.id,
        customer_name: extract_customer_name(conversation.contact, conversation.inbox.platform_name),
        platform: conversation.inbox.platform_name,
        recent_messages: format_recent_messages(conversation, exclude_message: message)
      }
      payload
    end

    def format_recent_messages(conversation, exclude_message: nil)
      messages = conversation.messages
                             .not_activity
                             .not_template
      messages = messages.where.not(id: exclude_message.id) if exclude_message&.id.present?

      messages.reorder(created_at: :desc)
              .limit(10)
              .map do |message|
        message_data = {
          conversation_id: message.conversation_id,
          message_type: message.message_type,
          content: message.content,
          customer_name: extract_customer_name(conversation.contact, conversation.inbox.platform_name),
          created_at: message.created_at,
          is_follow_up_message: message.content_attributes['follow_up'] || false,
          is_image_attached: message_has_image?(message),
          is_story_mentioned: is_story_mentioned?(message),
          metadata: message.metadata
        }

        message_data
      end
    end

    def message_has_image?(message)
      return false if message.nil?

      message.attachments.exists?(file_type: :image)
    end

    def is_story_mentioned?(message)
      return false if message.nil?

      message.content_attributes[:image_type] == 'story_mention'
    end

    def build_request_headers
      {
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        'Authorization' => "Bearer #{AUTH_TOKEN}"
      }
    end

    def parse_stark_response(response , message = nil)
      data = response['body']['data']
      customer_data = data['customer'].is_a?(Hash) ? data['customer'] : {}

      platform = conversation.inbox.platform_name
      handoff_customer_name = (customer_data['name'].presence ||
                               extract_customer_name(conversation.contact, platform))&.titleize
      handoff_customer_phone = customer_data['phone'].presence || '(N/A)'
      handoff_customer_email = customer_data['email'].presence || '(N/A)'

      refined_customer_data = {
        'name' => handoff_customer_name,
        'phone' => handoff_customer_phone,
        'email' => handoff_customer_email
      }

      if data['human_redirect']
        handoff_reason = data['handoff_reason']
        message_text = message.content
        ConversationHandoffService.new(conversation).process_handoff(refined_customer_data, handoff_reason , message_text)
      end

      {
        'content' => data['answer'],
        'action' => nil,
        'stop_follow_up' => data['stop_follow_up'],
        'attachments' => data['attachments'] || [],
        'metadata' => data['metadata'] || {},
        'is_spam' => data['is_spam']
      }
    end

    def error_response?(response)
      return true unless response.is_a?(Hash)
      return true unless response['body'].is_a?(Hash)

      response['body']['status'] == 'error' ||
        (response['metadata'] && response['metadata']['status_code'].to_i >= 400)
    end

    def handle_error_response(response)
      error_message = response.dig('body', 'message')
      errors = response.dig('body', 'errors')
      status_code = response.dig('metadata', 'status_code')

      error_details = {
        message: error_message,
        errors: errors,
        status_code: status_code
      }

      Rails.logger.error("Stark API Error: #{error_details}")
      raise StandardError, error_message || 'Stark API Error'
    end

    def log_stark_error(status_code, response, conversation = nil)
      message = response.dig('body', 'message')
      errors  = response.dig('body', 'errors')

      slack_message = case status_code
                      when 400
                        Stark::SlackMessageFormatter.format_http_error(400, message, errors, conversation)
                      when 500
                        Stark::SlackMessageFormatter.format_http_error(500, message, nil, conversation)
                      else
                        Stark::SlackMessageFormatter.format_unexpected_response(response, conversation)
                      end

      log_and_notify_slack(slack_message)
    end

    def log_and_notify_slack(message)
      Rails.logger.error(message)
      SlackNotifierService.call(
        text: message
      )
    end

    def extract_customer_name(contact, platform)
      return nil if contact.nil?

      # Website: Only send name if contact has email (meaning they entered it and name was updated from random)
      if platform == 'Website'
        return contact.name if contact.email.present?
        return nil
      end

      # Instagram: Prefer username over display name
      if platform == 'Instagram'
        return contact.additional_attributes&.dig('social_instagram_user_name') ||
               contact.additional_attributes&.dig('social_profiles', 'instagram') ||
               contact.name
      end

      # Facebook: Use name (could also check social_profiles if available)
      if platform == 'Facebook'
        return contact.additional_attributes&.dig('social_profiles', 'facebook') ||
               contact.name
      end

      # All other platforms: Use contact name
      contact.name
    end
  end
end
