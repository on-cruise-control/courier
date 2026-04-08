module Stark
  class CommentAnalysisService
    include StarkRetryable

    MAX_RETRIES = 1
    RETRY_DELAY = 3

    def analyze(comment, dealership_id, post_url = nil)
      return nil if comment.blank? || dealership_id.blank?

      retries = 0
      begin
        response = make_api_request(comment, dealership_id, post_url)
        Rails.logger.info "🔍 Stark API Response: #{response.inspect}"
        
        status_code = response.dig('metadata', 'status_code').to_i

        case status_code
        when 200
          {
            sentiment_label: response.dig('body', 'data', 'sentiment_label'),
            reply: response.dig('body', 'data', 'reply'),
            status: 'success'
          }
        when 400, 500
          Rails.logger.error("Stark API Error (#{status_code}): #{response.dig('body', 'message')}")
          { status: 'error', message: response.dig('body', 'message') }
        else
          Rails.logger.error("Stark API Unexpected Response: #{response.inspect}")
          { status: 'error', message: 'Unexpected response from Stark' }
        end
      rescue StandardError => e
        retries += 1
        if retries <= MAX_RETRIES
          Rails.logger.warn("Stark comment API error encountered (#{e.message}). Attempt #{retries} of #{MAX_RETRIES}. Retrying...")
          sleep(RETRY_DELAY)
          retry
        end

        Rails.logger.error("Stark comment API General Error: #{e.message}")
        { status: 'error', message: e.message }
      end
    end

    private

    def make_api_request(comment, dealership_id, post_url = nil)
      stark_endpoint = GlobalConfig.get_value('STARK_COMMENT_ANALYSIS_ENDPOINT')

      payload = {
        comment: comment,
        dealership_id: dealership_id
      }
      payload[:post_url] = post_url if post_url.present?

      response = HTTParty.post(
        stark_endpoint,
        body: payload.to_json,
        headers: build_request_headers,
        timeout: 60
      )

      parse_response_body(response)
    end

    def build_request_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV.fetch('STARK_API_KEY')}"
      }
    end

    def parse_response_body(response)
      return nil unless response&.body

      JSON.parse(response.body)
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse Stark response: #{e.message}")
      raise StandardError, 'Invalid response format from Stark server'
    end
  end
end
