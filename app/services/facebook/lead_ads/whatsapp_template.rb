# Submits the lead message to WhatsApp for review and tells whether an inbox can use it yet
class Facebook::LeadAds::WhatsappTemplate
  LANGUAGE = 'en'.freeze
  META_API_VERSION = 'v14.0'.freeze
  REJECTED = %w[rejected disabled paused failed unsubmitted].freeze

  pattr_initialize [:inbox!]

  def self.whatsapp_inboxes
    Inbox.where(channel_type: %w[Channel::Whatsapp Channel::TwilioSms]).select do |inbox|
      inbox.channel_type == 'Channel::Whatsapp' || inbox.channel.whatsapp?
    end
  end

  # approved, pending, rejected or missing (never submitted)
  def status
    entry = find_entry
    return 'missing' unless entry

    value = entry['status'].to_s.downcase
    return 'approved' if value == 'approved'

    REJECTED.include?(value) ? 'rejected' : 'pending'
  end

  # Re-reads the status from WhatsApp, and submits the message when the inbox has never had it
  def ready_status
    return 'approved' if status == 'approved'

    refresh
    submit if status == 'missing'
    status
  end

  def submit
    refresh
    return if find_entry

    twilio? ? submit_to_twilio : submit_to_meta
    Facebook::LeadAds::Message.record_submission_error(inbox.id, nil)
    refresh
  rescue StandardError => e
    Facebook::LeadAds::Message.record_submission_error(inbox.id, e.message)
    raise
  end

  def delete(template_name)
    twilio? ? delete_from_twilio(template_name) : delete_from_meta(template_name)
    refresh
  end

  def error
    Facebook::LeadAds::Message.submission_errors[inbox.id.to_s]
  end

  def template_params
    entry = find_entry
    return { 'name' => name, 'language' => entry['language'], 'processed_params' => {} } if twilio?

    { 'name' => name, 'namespace' => entry['namespace'], 'category' => entry['category'], 'language' => entry['language'],
      'processed_params' => {} }
  end

  private

  delegate :channel, to: :inbox

  def name
    @name ||= Facebook::LeadAds::Message.whatsapp_template_name
  end

  def twilio?
    inbox.channel_type == 'Channel::TwilioSms'
  end

  def find_entry
    channel.reload
    if twilio?
      channel.content_templates&.dig('templates')&.find { |entry| entry['friendly_name'] == name }
    else
      channel.message_templates&.find { |entry| entry['name'] == name }
    end
  end

  def refresh
    twilio? ? Twilio::TemplateSyncService.new(channel: channel).call : channel.sync_templates
  end

  def submit_to_twilio
    service = Twilio::TemplateManagementService.new(channel: channel)
    created = service.create_template(name: name, body: body, language: LANGUAGE)
    service.submit_for_whatsapp_approval(created['sid'], name: name, category: 'UTILITY')
  end

  def submit_to_meta
    raise 'Templates can only be created for WhatsApp Cloud inboxes' unless channel.provider == 'whatsapp_cloud'

    payload = { name: name, language: LANGUAGE, category: 'UTILITY', components: [{ type: 'BODY', text: body }] }
    response = HTTParty.post(meta_templates_url, headers: channel.api_headers, body: payload.to_json)
    raise response.dig('error', 'error_user_msg').presence || response.dig('error', 'message') || 'Template creation failed' unless response.success?
  end

  def delete_from_twilio(template_name)
    entry = channel.content_templates&.dig('templates')&.find { |item| item['friendly_name'] == template_name }
    Twilio::TemplateManagementService.new(channel: channel).delete_template(entry['content_sid']) if entry
  end

  def delete_from_meta(template_name)
    return unless channel.provider == 'whatsapp_cloud'

    HTTParty.delete("#{meta_templates_url}?name=#{template_name}", headers: channel.api_headers)
  end

  def body
    Facebook::LeadAds::Message.template
  end

  def meta_templates_url
    base = ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')
    "#{base}/#{META_API_VERSION}/#{channel.provider_config['business_account_id']}/message_templates"
  end
end
