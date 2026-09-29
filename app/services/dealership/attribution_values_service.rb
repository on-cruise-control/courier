# frozen_string_literal: true

class Dealership::AttributionValuesService
  include HTTParty

  class ApiError < StandardError
    attr_reader :code, :response

    def initialize(message = nil, code = nil, response = nil)
      @code = code
      @response = response
      super(message)
    end
  end

  def initialize(dealership_id)
    @dealership_id = dealership_id
    @base_uri = GlobalConfig.get('DEALERSHIP_API_BASE_URL')&.[]('DEALERSHIP_API_BASE_URL') ||
                ENV.fetch('DEALERSHIP_API_BASE_URL', 'https://api.example.com')
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')&.[]('DEALERSHIP_API_KEY') ||
               ENV.fetch('DEALERSHIP_API_KEY', nil)
  end

  def fetch_values
    return {} if @dealership_id.blank?

    begin
      response = make_request
      parse_response(response)
    rescue ApiError => e
      Rails.logger.error("Dealership Attribution Values API Error (#{e.code}): #{e.message}")
      {}
    rescue StandardError => e
      Rails.logger.error("Dealership Attribution Values Service Error: #{e.message}")
      {}
    end
  end

  private

  def make_request
    url = "#{@base_uri}/api/v1/dealerships/#{@dealership_id}/attribution/values"

    headers = { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
    headers['Authorization'] = "Bearer #{@api_key}" if @api_key.present?

    response = self.class.get(url, headers: headers, timeout: 30)
    handle_response(response)
  end

  def handle_response(response)
    case response.code
    when 200..299
      response
    when 404
      raise ApiError.new('Dealership not found', 404, response)
    when 500..599
      raise ApiError.new('Dealership API server error', response.code, response)
    else
      raise ApiError.new("Unexpected response: #{response.code}", response.code, response)
    end
  end

  def parse_response(response)
    body = response.parsed_response
    return {} unless body.is_a?(Hash)

    body.dig('body', 'data') || body['data'] || {}
  rescue JSON::ParserError => e
    raise ApiError.new("Failed to parse response: #{e.message}", response.code, response)
  end
end
