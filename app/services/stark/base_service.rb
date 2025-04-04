class Stark::BaseService
  include HTTParty

  BASE_URL   = 'https://api.stark.mahantsolutions.com/api/v1/stark/message/'.freeze
  AUTH_TOKEN = 'i6NpaCOX7aDXVWfHsnxgJKYuDftBfhxb'.freeze

  def send_request(payload)
    response = HTTParty.post(BASE_URL, body: payload.to_json, headers: headers)
    process_response(response)
  rescue HTTParty::Error => e
    Rails.logger.debug { "httparty error: #{e.message}" }
    raise StandardError, 'Failed to send request'
  end

  private

  def headers
    {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{AUTH_TOKEN}"
    }
  end

  def process_response(response)
    parsed_response = response.parsed_response
    Rails.logger.debug { "Response: #{parsed_response.inspect}" }

    if response.success? && parsed_response['body']['status'] == 'success'
      handle_success(parsed_response)
    else
      handle_error(parsed_response)
    end
  end

  def handle_success(parsed_response)
    parsed_response
  end

  def handle_error(parsed_response)
    parsed_response
  end

  def generate_session_id
    SecureRandom.hex(8)
  end
end
