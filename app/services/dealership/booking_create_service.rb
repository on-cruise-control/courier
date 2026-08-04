# frozen_string_literal: true

class Dealership::BookingCreateService
  include HTTParty

  def initialize(conversation, force: false, type: nil, summary: nil)
    @conversation = conversation
    @contact = conversation.contact
    @account = conversation.account
    @inbox = conversation.inbox
    @force = force
    @type_override    = type
    @summary_override = summary
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def perform
    return unless enabled?

    unless @force || whatsapp_or_sms?
      return
    end

    url = "#{@base_url}/api/v1/bookings"
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    }

    payload_data = payload
    return if payload_data.blank?

    response = self.class.post(url, body: payload_data.to_json, headers: headers)
 
    if response.success?
      Rails.logger.info "--Dealership booking create successful for conversation_id: #{@conversation.id}, response: #{response.body}"
      update_last_call_timestamp
    else
      Rails.logger.error "--Dealership booking create failed for conversation_id: #{@conversation.id}: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "--Dealership booking create exception for conversation_id: #{@conversation.id}: #{e.message}"
  end

  private

  def enabled?
    @base_url.present? && @api_key.present? && @account.dealership_id.present?
  end

  def whatsapp_or_sms?
    return false if @inbox.nil?

    @inbox.whatsapp? || @inbox.sms? || @inbox.twilio?
  end

  def payload
    payload_data = {
      dealership_id: @account.dealership_id,
      contact_id: @contact.id,
      conversation_id: @conversation.id,
      account_id: @account.id,
      platform: @inbox.platform_name,
      type: @type_override || 'booking',
      status: 'completed'
    }

    if @summary_override.present?
      payload_data[:summary] = @summary_override
    else
      payload_data[:recent_messages] = format_recent_messages
    end

    payload_data
  end

  def format_recent_messages
    last_call_at = @conversation.additional_attributes['last_booking_api_call_at']
    messages = @conversation.messages.where(message_type: [:incoming, :outgoing]).where(private: false)
    messages = messages.where('messages.created_at > ?', last_call_at) if last_call_at.present?

    messages.reorder(created_at: :desc).map do |message|
      {
        conversation_id: message.conversation_id,
        message_type: message.message_type,
        content: message.content,
        created_at: message.created_at
      }
    end
  end

  def update_last_call_timestamp
    @conversation.with_lock do
      @conversation.update_columns(
        additional_attributes: @conversation.additional_attributes.merge('last_booking_api_call_at' => Time.now.utc)
      )
    end
  end
end
