# frozen_string_literal: true

class Dealership::WalletBalanceService
  include HTTParty

  def initialize(dealership_id, current_month_usage:)
    @dealership_id = dealership_id
    @current_month_usage = current_month_usage
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def fetch_balance
    return nil unless enabled?

    response = self.class.get(
      url,
      headers: headers,
      query: { current_month_usage: @current_month_usage }
    )

    unless response.success?
      Rails.logger.error "--Dealership wallet balance fetch failed for dealership_id: #{@dealership_id}: #{response.code} #{response.body}"
      return nil
    end

    response.parsed_response.dig('body', 'data')
  rescue StandardError => e
    Rails.logger.error "--Dealership wallet balance fetch exception for dealership_id: #{@dealership_id}: #{e.message}"
    nil
  end

  private

  def enabled?
    @base_url.present? && @api_key.present? && @dealership_id.present?
  end

  def url
    "#{@base_url}/api/v1/dealerships/#{@dealership_id}/wallet/balance"
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    }
  end
end
