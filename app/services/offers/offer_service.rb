# frozen_string_literal: true

class Offers::OfferService
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

  def fetch_offers
    return { results: [] } if @dealership_id.blank?

    response = self.class.get(index_url, query: { dealership: @dealership_id }, headers: request_headers, timeout: 30)
    parse_list(handle_response(response))
  rescue ApiError => e
    Rails.logger.error("Dealership Offers API Error (#{e.code}): #{e.message}")
    { results: [], error: e.message, status: e.code }
  rescue StandardError => e
    Rails.logger.error("Dealership Offers Service Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    { results: [], error: 'Internal Service Error', status: 500 }
  end

  def create_offer(params)
    return { error: 'Dealership is not configured for this account', status: 422 } if @dealership_id.blank?

    body = { dealership: @dealership_id }.merge(offer_body(params))
    response = self.class.post(index_url, body: body, headers: request_headers, timeout: 30, stream_body: false)
    parse_single(handle_response(response))
  rescue ApiError => e
    Rails.logger.error("Dealership Offer Create API Error (#{e.code}): #{e.message}")
    { error: e.message, status: e.code }
  rescue StandardError => e
    Rails.logger.error("Dealership Offer Create Service Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    { error: 'Internal Service Error', status: 500 }
  end

  def update_offer(offer_id, params)
    return { error: 'Offer ID is required', status: 422 } if offer_id.blank?

    body = offer_body(params)
    response = self.class.put("#{index_url}/#{offer_id}", body: body, headers: request_headers, timeout: 30, stream_body: false)
    parse_single(handle_response(response))
  rescue ApiError => e
    Rails.logger.error("Dealership Offer Update API Error (#{e.code}): #{e.message}")
    { error: e.message, status: e.code }
  rescue StandardError => e
    Rails.logger.error("Dealership Offer Update Service Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    { error: 'Internal Service Error', status: 500 }
  end

  def delete_offer(offer_id)
    return { error: 'Offer ID is required', status: 422 } if offer_id.blank?

    response = self.class.delete("#{index_url}/#{offer_id}", headers: request_headers, timeout: 30)
    handle_response(response)
    { success: true }
  rescue ApiError => e
    Rails.logger.error("Dealership Offer Delete API Error (#{e.code}): #{e.message}")
    { error: e.message, status: e.code }
  rescue StandardError => e
    Rails.logger.error("Dealership Offer Delete Service Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    { error: 'Internal Service Error', status: 500 }
  end

  private

  def offer_body(params)
    body = {}
    body[:title] = params[:title] if params[:title].present?
    body[:start_date] = params[:start_date] if params[:start_date].present?
    body[:end_date] = params[:end_date] if params[:end_date].present?
    body[:offer_document] = params[:offer_document] if params[:offer_document].present?
    body
  end

  def index_url
    "#{@base_uri}/api/v1/offer-and-promotions"
  end

  def request_headers
    headers = { 'Accept' => 'application/json' }
    headers['Authorization'] = "Bearer #{@api_key}" if @api_key.present?
    headers
  end

  def handle_response(response)
    case response.code
    when 200..299
      response
    when 401
      raise ApiError.new('Unauthorized: Invalid API Key', 401, response)
    when 404
      raise ApiError.new('Offer not found', 404, response)
    when 422
      raise ApiError.new(validation_error_message(response), 422, response)
    when 500..599
      raise ApiError.new('Dealership API server error', response.code, response)
    else
      raise ApiError.new("Unexpected response: #{response.code}", response.code, response)
    end
  end

  def validation_error_message(response)
    body = response.parsed_response
    body.is_a?(Hash) ? (body['message'] || body['error'] || 'Validation failed') : 'Validation failed'
  end

  def parse_list(response)
    body = response.parsed_response
    return { results: [] } unless body.is_a?(Hash)

    data = body.dig('body', 'data') || body['data'] || []
    { results: Array(data) }
  end

  def parse_single(response)
    body = response.parsed_response
    return {} unless body.is_a?(Hash)

    body.dig('body', 'data') || body['data'] || body
  end
end
