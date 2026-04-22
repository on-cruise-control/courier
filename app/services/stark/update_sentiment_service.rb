module Stark
  class UpdateSentimentService
    def update(stark_comment_id, reason: nil)
      return { status: 'error', message: 'Missing comment ID' } if stark_comment_id.blank?

      endpoint = GlobalConfig.get_value('STARK_COMMENT_ANALYSIS_ENDPOINT')
      url = "#{endpoint}/#{stark_comment_id}"

      payload = { sentiment_label: 'Positive' }
      payload[:reason] = reason if reason.present?

      Rails.logger.info "🔄 Stark UpdateSentiment → Payload: #{payload.to_json}"

      response = HTTParty.put(
        url,
        body: payload.to_json,
        headers: build_request_headers,
        timeout: 30
      )

      Rails.logger.info "🔄 Stark UpdateSentiment Response: #{response.body}"

      parsed = JSON.parse(response.body)
      status_code = parsed.dig('metadata', 'status_code').to_i

      if status_code == 200
        { status: 'success' }
      else
        Rails.logger.error "❌ Stark UpdateSentiment → Failed: #{parsed.dig('body', 'message')}"
        { status: 'error', message: parsed.dig('body', 'message') }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "❌ Stark UpdateSentiment → Raw response was: #{response&.body}"
      { status: 'error', message: 'Invalid response format from Stark server' }
    rescue StandardError => e
      Rails.logger.error "❌ Stark UpdateSentiment → Error: #{e.message}"
      { status: 'error', message: e.message }
    end

    private

    def build_request_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV.fetch('STARK_API_KEY')}"
      }
    end
  end
end
