class Twilio::TemplateSyncService
  pattr_initialize [:channel!]

  def call
    fetch_templates_from_twilio
    update_channel_templates
    mark_templates_updated
  rescue Twilio::REST::TwilioError => e
    Rails.logger.error("Twilio template sync failed: #{e.message}")
    false
  end

  private

  def fetch_templates_from_twilio
    @templates = client.content.v1.contents.list(limit: 1000)
  end

  def update_channel_templates
    formatted_templates = @templates.map { |template| format_template(template) }

    channel.update!(
      content_templates: { templates: formatted_templates },
      content_templates_last_updated: Time.current
    )
  end

  def format_template(template)
    approval_info = fetch_whatsapp_approval_info(template.sid)
    {
      content_sid: template.sid,
      friendly_name: template.friendly_name,
      language: template.language,
      status: approval_info[:status],
      template_type: derive_template_type(template),
      media_type: derive_media_type(template),
      variables: template.variables || {},
      category: approval_info[:category],
      body: extract_body_content(template),
      types: template.types,
      created_at: template.date_created,
      updated_at: template.date_updated
    }
  end

  def mark_templates_updated
    channel.update!(content_templates_last_updated: Time.current)
  end

  def client
    @client ||= channel.send(:client)
  end

  def fetch_whatsapp_approval_info(content_sid)
    approval = client.content.v1.contents(content_sid).approval_fetch.fetch
    {
      status: approval.whatsapp&.dig('status') || 'unsubmitted',
      category: approval.whatsapp&.dig('category')&.downcase
    }
  rescue Twilio::REST::TwilioError => e
    Rails.logger.warn("Could not fetch approval info for #{content_sid}: #{e.message}")
    { status: 'unsubmitted', category: nil }
  end

  def derive_template_type(template)
    template_types = template.types.keys

    if template_types.include?('twilio/media')
      'media'
    elsif template_types.include?('twilio/quick-reply')
      'quick_reply'
    elsif template_types.include?('twilio/call-to-action')
      'call_to_action'
    elsif template_types.include?('twilio/list-picker')
      'list_picker'
    elsif template_types.include?('twilio/card')
      'card'
    elsif template_types.include?('twilio/catalog')
      'catalog'
    elsif template_types.include?('twilio/carousel')
      'carousel'
    else
      'text'
    end
  end

  def derive_media_type(template)
    return nil unless derive_template_type(template) == 'media'

    media_content = template.types['twilio/media']
    return nil unless media_content

    if media_content['image']
      'image'
    elsif media_content['video']
      'video'
    elsif media_content['document']
      'document'
    end
  end

  def extract_body_content(template)
    template.types.each_value do |type_data|
      return type_data['body'] if type_data.is_a?(Hash) && type_data['body'].present?
    end
    ''
  end
end
