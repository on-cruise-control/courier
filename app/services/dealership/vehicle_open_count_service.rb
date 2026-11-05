# frozen_string_literal: true

class Dealership::VehicleOpenCountService
  include HTTParty

  FILTER_KEYS = %i[from_date to_date period].freeze

  def initialize(dealership_id, filters = {})
    @dealership_id = dealership_id
    @filters = filters.slice(*FILTER_KEYS).compact_blank
    @base_uri = GlobalConfig.get('DEALERSHIP_API_BASE_URL')&.[]('DEALERSHIP_API_BASE_URL') ||
                ENV.fetch('DEALERSHIP_API_BASE_URL', 'https://api.example.com')
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')&.[]('DEALERSHIP_API_KEY') ||
               ENV.fetch('DEALERSHIP_API_KEY', nil)
  end

  def fetch_count
    return {} if @dealership_id.blank?

    response = self.class.get(url, query: @filters, headers: headers, timeout: 30)
    return response.parsed_response.dig('body', 'data') || {} if response.success?

    Rails.logger.error("Dealership vehicle open count failed (#{response.code}): #{response.body}")
    {}
  rescue StandardError => e
    Rails.logger.error("Dealership vehicle open count error: #{e.message}")
    {}
  end

  private

  def url
    "#{@base_uri}/api/v1/dealerships/#{@dealership_id}/vehicleopenlog/count"
  end

  def headers
    { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }.tap do |h|
      h['Authorization'] = "Bearer #{@api_key}" if @api_key.present?
    end
  end
end
