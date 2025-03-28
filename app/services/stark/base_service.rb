require 'net/http'
require 'uri'
require 'json'

class Stark::BaseService
  BASE_URL = 'https://api.stark.mahantsolutions.com/api/v1/stark/message'.freeze

  def initialize(session_id: nil)
    @session_id = session_id || generate_session_id
  end

  def send_request(payload)
    uri = URI(BASE_URL)
    request = Net::HTTP::Post.new(uri, headers)
    request.body = payload.to_json
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    process_response(response)
  end

  private

  def headers
    {
      'content-type' => 'application/json',
      'Authorization' => "Bearer "
    }
  end

  def process_response(response)
    parse_response = JSON.parse(response.body)
    if response.is_a?(Net::HTTPSuccess) && parsed_response['status'] == 'success'
      handle_success(parse_response)
    else
      handle_error(parse_response)
    end
  end

  def handle_success(parsed_response)
    parsed_response['data']
  end

  def handle_error(parsed_response)
    errors = parsed_response.fetch('errors', {})
    error_messages = errors.map { |field, messages| "#{field}: #{messages.join(', ')}" }.join(' | ')
    raise RuntimeError, "Error: #{parsed_response['message']} | Details: #{error_messages}".strip
  end

  def generate_session_id
    SecureRandom.hex(8)
  end
end
