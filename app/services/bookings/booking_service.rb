# frozen_string_literal: true

module Bookings
  class BookingService
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

    def fetch_bookings(params = {})
      return { results: [], count: 0 } if @dealership_id.blank?

      begin
        response = make_index_request(params)
        parse_response(response)
      rescue ApiError => e
        Rails.logger.error("Dealership Bookings API Error (#{e.code}): #{e.message}")
        { results: [], count: 0, error: e.message }
      rescue StandardError => e
        Rails.logger.error("Dealership Bookings Service Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        { results: [], count: 0, error: 'Internal Service Error' }
      end
    end

    def find_booking(booking_id)
      return { error: 'Booking ID is required' } if booking_id.blank?

      begin
        response = make_index_request(
          id: booking_id, 
          page_size: 1, 
          created_at_after: '2010-01-01'
        )
        results = parse_response(response)[:results]
        record = results.find { |b| b['id'] == booking_id }
        
        if record
          record
        else
          response = make_index_request(page_size: 50, created_at_after: '2010-01-01')
          results = parse_response(response)[:results]
          record = results.find { |b| b['id'] == booking_id }
          
          if record
            record
          else
            Rails.logger.warn("Booking with ID #{booking_id} not found after wide search.")
            { error: 'Booking not found' }
          end
        end
      rescue ApiError => e
        Rails.logger.error("Dealership Booking Find API Error (#{e.code}): #{e.message}")
        { error: e.message }
      rescue StandardError => e
        Rails.logger.error("Dealership Booking Find Service Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        { error: 'Internal Service Error' }
      end
    end

    private

    def make_index_request(params)
      url = "#{@base_uri}/api/v1/bookings"
      
      query_params = {
        dealership_id: @dealership_id,
        page: params[:page] || 1,
        page_size: params[:page_size] || 10
      }
      query_params[:id] = params[:id] if params[:id].present?
      query_params[:created_at_after] = params[:created_at_after] if params[:created_at_after].present?
      query_params[:created_at_before] = params[:created_at_before] if params[:created_at_before].present?
      
      headers = { 
        'Content-Type' => 'application/json', 
        'Accept' => 'application/json' 
      }
      headers['Authorization'] = "Bearer #{@api_key}" if @api_key.present?
      
      response = self.class.get(url, query: query_params, headers: headers, timeout: 30)
      handle_response(response)
    end


    def handle_response(response)
      case response.code
      when 200..299
        response
      when 401
        raise ApiError.new('Unauthorized: Invalid API Key', 401, response)
      when 404
        raise ApiError.new('Resource not found', 404, response)
      when 500..599
        raise ApiError.new('Dealership API server error', response.code, response)
      else
        raise ApiError.new("Unexpected response: #{response.code}", response.code, response)
      end
    end

    def parse_response(response)
      body = response.parsed_response
      return { results: [], count: 0 } unless body.is_a?(Hash)

      data = body.dig('body', 'data') || body['data'] || body
      
      if data.is_a?(Hash) && data['results'].is_a?(Array)
        { 
          results: data['results'], 
          count: data['count'] || data['results'].size,
          next: data['next'],
          previous: data['previous']
        }
      else
        { results: [], count: 0 }
      end
    rescue JSON::ParserError => e
      raise ApiError.new("Failed to parse response: #{e.message}", response.code, response)
    end
  end
end
