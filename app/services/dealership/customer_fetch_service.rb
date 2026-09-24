# frozen_string_literal: true

class Dealership::CustomerFetchService
  include HTTParty

  def initialize(contact)
    @contact = contact
    @account = contact.account
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def perform
    return nil unless enabled?

    url = "#{@base_url}/api/v1/customers/#{@contact.id}"
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    }

    response = self.class.get(url, headers: headers)

    if response.success?
      response.parsed_response.dig('body', 'data', 'lead_attribution')
    else
      Rails.logger.error "--Dealership customer fetch failed for contact_id: #{@contact.id}: #{response.code} #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "--Dealership customer fetch exception for contact_id: #{@contact.id}: #{e.message}"
    nil
  end

  private

  def enabled?
    @base_url.present? && @api_key.present? && @account.dealership_id.present?
  end
end
