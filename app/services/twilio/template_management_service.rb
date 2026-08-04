require 'net/http'

class Twilio::TemplateManagementService
  CONTENT_API_BASE = 'https://content.twilio.com'.freeze

  pattr_initialize [:channel!]

  def create_template(name:, body:, language: 'en', variables: {}, template_type: 'twilio/text',
                      buttons: [], actions: [], card_actions: [], media_url: nil, title: nil,
                      list_button: 'Select', list_items: [])
    payload = {
      friendly_name: name,
      language: language,
      types: build_types(template_type, body, buttons, actions, card_actions, media_url, title, list_button, list_items)
    }
    payload[:variables] = variables if variables.present?

    response = content_api_post('/v1/Content', payload)
    raise StandardError, twilio_error(response) unless response['sid']

    response
  end

  def delete_template(content_sid)
    content_api_delete("/v1/Content/#{content_sid}")
  end

  def update_template(content_sid, **params)
    delete_template(content_sid)
    create_template(**params)
  end

  def fetch_template(content_sid)
    uri = URI("#{CONTENT_API_BASE}/v1/Content/#{content_sid}")
    req = Net::HTTP::Get.new(uri)
    req.basic_auth(*credentials)
    http_request(uri, req)
  end

  def submit_for_whatsapp_approval(content_sid, name:, category: 'UTILITY')
    payload = { name: name, category: category }
    response = content_api_post("/v1/Content/#{content_sid}/ApprovalRequests/whatsapp", payload)
    raise StandardError, twilio_error(response) if response['status'] == 'error' || response['code']

    response
  end

  def update_variables_and_submit(content_sid, variable_samples:, name:, category: 'UTILITY')
    current = fetch_template(content_sid)
    raise StandardError, twilio_error(current) unless current['sid']

    delete_template(content_sid)

    recreated = content_api_post('/v1/Content', {
      friendly_name: current['friendly_name'],
      language: current['language'],
      variables: variable_samples,
      types: current['types']
    })
    raise StandardError, twilio_error(recreated) unless recreated['sid']

    submit_for_whatsapp_approval(recreated['sid'], name: name, category: category)
    recreated
  end

  private

  def content_api_post(path, payload)
    uri = URI("#{CONTENT_API_BASE}#{path}")
    req = Net::HTTP::Post.new(uri)
    req.basic_auth(*credentials)
    req['Content-Type'] = 'application/json'
    req.body = payload.to_json
    http_request(uri, req)
  end

  def content_api_delete(path)
    uri = URI("#{CONTENT_API_BASE}#{path}")
    req = Net::HTTP::Delete.new(uri)
    req.basic_auth(*credentials)
    http_request(uri, req)
  end

  def http_request(uri, req)
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
    return {} if response.body.blank?

    JSON.parse(response.body)
  rescue StandardError => e
    raise StandardError, e.message
  end

  def credentials
    if channel.api_key_sid.present?
      [channel.api_key_sid, channel.auth_token]
    else
      [channel.account_sid, channel.auth_token]
    end
  end

  def twilio_error(response)
    response['message'] || response['error_message'] || 'Unknown Twilio error'
  end

  def build_types(template_type, body, buttons, actions, card_actions, media_url, title, list_button, list_items)
    case template_type
    when 'twilio/quick-reply'
      {
        'twilio/quick-reply': {
          body: body,
          actions: buttons.map { |b| { type: 'QUICK_REPLY', title: b[:title], id: b[:id].presence || b[:title] } }
        }
      }
    when 'twilio/media'
      payload = { body: body }
      payload[:media] = [media_url] if media_url.present?
      { 'twilio/media': payload }
    when 'twilio/call-to-action'
      {
        'twilio/call-to-action': {
          body: body,
          actions: actions.map { |a| build_cta_action(a) }
        }
      }
    when 'twilio/card'
      payload = { body: body }
      payload[:title] = title if title.present?
      payload[:media] = [media_url] if media_url.present?
      payload[:actions] = card_actions.map { |a| build_card_action(a) } if card_actions.present?
      { 'twilio/card': payload }
    when 'twilio/list-picker'
      {
        'twilio/list-picker': {
          body: body,
          button: list_button.presence || 'Select',
          items: list_items.map { |item| { id: item[:id].presence || item[:title], title: item[:title] } }
        }
      }
    else
      { 'twilio/text': { body: body } }
    end
  end

  def build_cta_action(action)
    base = { type: action[:type], title: action[:title] }
    action[:type] == 'URL' ? base.merge(url: action[:url]) : base.merge(phone: action[:phone])
  end

  def build_card_action(action)
    base = { type: action[:type], title: action[:title] }
    case action[:type]
    when 'URL' then base.merge(url: action[:url])
    when 'PHONE_NUMBER', 'VOICE_CALL' then base.merge(phone: action[:phone])
    when 'COPY_CODE' then base.merge(code: action[:code])
    else base.merge(id: action[:id].presence || action[:title])
    end
  end
end
