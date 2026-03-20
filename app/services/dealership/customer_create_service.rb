# frozen_string_literal: true

class Dealership::CustomerCreateService
  include HTTParty

  def initialize(contact, inbox: nil)
    @contact = contact
    @inbox = inbox || contact.inboxes.first
    @account = contact.account
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def perform
    return unless enabled?

    unless whatsapp_or_sms?
      return
    end

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

  def whatsapp_or_sms?
    return false if @inbox.nil?

    @inbox.whatsapp? || @inbox.sms? || @inbox.twilio?
  end

  def payload
    {
      contact_id: @contact.id,
      account_id: @account.id,
      dealership_id: @account.dealership_id,
      name: @contact.name.presence,
      email: @contact.email.presence,
      phone: @contact.phone_number.presence
    }
  end
end
