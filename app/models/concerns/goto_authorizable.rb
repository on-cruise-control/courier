# GoTo OAuth tokens and message sending, shared by the SMS inbox channel and the account's SMS notification settings.
# Including models need access_token, access_token_expires_at, refresh_token, account_key and phone_number columns.
module GotoAuthorizable
  extend ActiveSupport::Concern

  AUTH_URL = 'https://authentication.logmeininc.com/oauth/authorize'.freeze
  TOKEN_URL = 'https://authentication.logmeininc.com/oauth/token'.freeze
  API_URL = 'https://api.goto.com'.freeze
  MEDIA_CONTENT_TYPES = %w[image/jpeg image/png image/gif].freeze
  MAX_MEDIA_SIZE = 2.megabytes

  included do
    encrypts :refresh_token, :access_token if Chatwoot.encryption_configured?
  end

  # The GoTo OAuth client belongs to the Cruise Control app and is configured once by the super admin.
  def client_id
    GlobalConfigService.load('GOTO_CLIENT_ID', nil)
  end

  def client_secret
    GlobalConfigService.load('GOTO_CLIENT_SECRET', nil)
  end

  def authorization_url(state, redirect_uri)
    "#{AUTH_URL}?#{{ client_id: client_id, response_type: 'code', redirect_uri: redirect_uri, state: state }.to_query}"
  end

  def authorize!(code, redirect_uri)
    store_tokens(request_token(grant_type: 'authorization_code', code: code, redirect_uri: redirect_uri))
  end

  def access_token!
    refresh_access_token! if access_token.blank? || access_token_expires_at < 1.minute.from_now
    access_token
  end

  def send_message(to:, body:, attachments: [])
    validate_media!(attachments)
    response = messaging_connection.post("/messaging/v2/accounts/#{account_key}/messages") do |req|
      req.headers['Authorization'] = "Bearer #{access_token!}"
      req.body = { request: Faraday::Multipart::ParamPart.new(message_request(to, body, attachments).to_json, 'application/json') }
      req.body[:attachments] = media_parts(attachments) if attachments.any?
    end
    raise response.body.to_s unless response.success?

    JSON.parse(response.body)['id']
  end

  private

  # The row lock makes concurrent jobs refresh once; the others reuse the freshly stored token.
  def refresh_access_token!
    with_lock do
      next if access_token.present? && access_token_expires_at > 1.minute.from_now

      store_tokens(request_token(grant_type: 'refresh_token', refresh_token: refresh_token))
    end
  end

  def request_token(params)
    credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")
    response = Faraday.post(TOKEN_URL, params) { |req| req.headers['Authorization'] = "Basic #{credentials}" }
    raise "GoTo token request failed: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  def store_tokens(data)
    update!(
      access_token: data['access_token'],
      access_token_expires_at: data['expires_in'].to_i.seconds.from_now,
      refresh_token: data['refresh_token'].presence || refresh_token
    )
  end

  # flat_encode sends every file under the same "attachments" part name, as GoTo expects.
  def messaging_connection
    Faraday.new(url: API_URL) { |f| f.request :multipart, flat_encode: true }
  end

  def validate_media!(attachments)
    raise 'GoTo only supports JPEG, PNG or GIF images' unless attachments.all? { |a| MEDIA_CONTENT_TYPES.include?(a.file.content_type) }
    raise 'GoTo attachments must be 2 MB or less in total' if attachments.sum { |a| a.file.byte_size } > MAX_MEDIA_SIZE
  end

  def media_parts(attachments)
    attachments.map do |attachment|
      Faraday::Multipart::FilePart.new(StringIO.new(attachment.file.blob.open(&:read)), attachment.file.content_type, attachment.file.filename.to_s)
    end
  end

  def message_request(to, body, attachments)
    text = body.present? ? [{ type: 'text', attributes: { text: body } }] : []
    images = attachments.map { |attachment| { type: 'image', attributes: { attachmentName: attachment.file.filename.to_s } } }
    {
      channel: 'SMS', from: phone_number, to: [to], type: 'simple',
      components: [{ type: 'body', components: text + images }]
    }
  end
end
