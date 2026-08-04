class Dealership::ActivationService
  include HTTParty

  def initialize(account)
    @account = account
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def perform(active:)
    return unless enabled?

    url = "#{@base_url}/api/v1/dealerships/#{@account.dealership_id}"
    body = { is_active: active }.to_json
    headers = {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    }

    response = self.class.put(url, body: body, headers: headers)
    
    if response.success?
      Rails.logger.info "Dealership account activation status update successful for dealership_id: #{@account.dealership_id},response: #{response.body} , body: #{body}"
    else
      Rails.logger.error "Dealership account activation status update failed: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "Dealership account activation status update exception: #{e.message}"
  end

  private

  def enabled?
    @base_url.present? && @api_key.present? && @account.dealership_id.present?
  end
end
