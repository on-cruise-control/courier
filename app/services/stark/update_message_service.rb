module Stark
  class UpdateMessageService
    def initialize(message)
      @message = message
    end

    def update_human_redirect(human_redirect:)
      return { status: 'error', message: 'Missing message' } if @message.blank?
      return { status: 'error', message: 'Missing Stark API base URL' } if stark_api_base_url.blank?
      response = HTTParty.put(
        "#{stark_api_base_url}/#{@message.metadata['stark_message_id']}",
        body: { human_redirect: human_redirect }.to_json,
        headers: build_request_headers,
        timeout: 30
      )

      Rails.logger.info("Stark UpdateMessage response for message #{@message.id}: #{response.body}")

      parsed_response = JSON.parse(response.body)
      status_code = parsed_response.dig('metadata', 'status_code').to_i
      
      if status_code == 200
        { status: 'success' }
      else
        error_message = parsed_response.dig('body', 'message') || 'Failed to update Stark message'
        Rails.logger.error("Stark UpdateMessage failed for message #{@message.id}: #{error_message}")
        { status: 'error', message: error_message }
      end
    rescue JSON::ParserError
      Rails.logger.error("Stark UpdateMessage invalid response for message #{@message.id}: #{response&.body}")
      { status: 'error', message: 'Invalid response format from Stark server' }
    rescue StandardError => e
      Rails.logger.error("Stark UpdateMessage error for message #{@message.id}: #{e.message}")
      { status: 'error', message: e.message }
    end

    private

    def build_request_headers
      {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV.fetch('STARK_API_KEY')}"
      }
    end

    def stark_api_base_url
      outgoing_url = AgentBot.where(bot_type:"stark").last.outgoing_url

      return if outgoing_url.blank?
      outgoing_url
    rescue URI::InvalidURIError => e
      Rails.logger.error("Invalid Stark outgoing URL for message #{@message.id}: #{e.message}")
      nil
    end
  end
end
