# frozen_string_literal: true

class Dealership::CustomerCreateService
  include HTTParty

  def initialize(contact, inbox: nil, conversation: nil, name: nil, email: nil, phone: nil)
    @contact = contact
    @inbox = inbox || contact.inboxes.first
    @conversation = conversation
    @account = contact.account
    @name_override  = name
    @email_override = email
    @phone_override = phone
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def perform
    return unless enabled?

    url = "#{@base_url}/api/v1/customers"
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    }

    response = self.class.post(url, body: payload.to_json, headers: headers)

    if response.success?
      Rails.logger.info "--Dealership customer create successful for contact_id: #{@contact.id}, response: #{response.body}"
    else
      Rails.logger.error "--Dealership customer create failed for contact_id: #{@contact.id}: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "--Dealership customer create exception for contact_id: #{@contact.id}: #{e.message}"
  end

  private

  def enabled?
    @base_url.present? && @api_key.present? && @account.dealership_id.present?
  end

  def payload
    {
      contact_id: @contact.id,
      account_id: @account.id,
      dealership_id: @account.dealership_id,
      name: @name_override.presence || @contact.name.presence,
      email: @email_override.presence || @contact.email.presence,
      phone: @phone_override.presence || @contact.phone_number.presence,
      whatsapp_number: whatsapp_number,
      sms_number: sms_number,
      referer_url: referer_url,
      ad_title: ad_title
    }
  end

  def contact_phone_number
    @phone_override.presence || @contact.phone_number.presence
  end

  def whatsapp_number
    return nil unless @inbox&.whatsapp? || @inbox&.twilio_whatsapp?

    contact_phone_number
  end

  def sms_number
    return nil unless @inbox&.sms? || (@inbox&.twilio? && !@inbox.twilio_whatsapp?)

    contact_phone_number
  end

  def referer_url
    @conversation&.additional_attributes&.dig('referer').presence || referral_attributes['source_url']
  end

  def ad_title
    referral_attributes['ad_title'] || referral_attributes['headline']
  end

  def referral_attributes
    @referral_attributes ||= @conversation&.messages&.incoming&.first&.content_attributes&.dig('referral') || {}
  end
end
