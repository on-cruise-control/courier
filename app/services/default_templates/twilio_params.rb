class DefaultTemplates::TwilioParams
  pattr_initialize :default_template

  def to_h
    { name: default_template.name, language: default_template.language, variables: variable_samples }.merge(type_params)
  end

  private

  def content
    @content ||= default_template.content.with_indifferent_access
  end

  def item
    @item ||= content[:items].to_a.first || {}
  end

  # WhatsApp approval needs a sample value for every {{n}} variable.
  def variable_samples
    keys = content.to_json.scan(/{{(\d+)}}/).flatten.uniq
    keys.index_with { |key| "Sample #{key}" }
  end

  def type_params
    case default_template.category
    when 'quick_reply' then quick_reply_params
    when 'media' then { template_type: 'twilio/media', body: content[:caption].to_s, media_url: content[:media_url] }
    when 'call_to_action' then { template_type: 'twilio/call-to-action', body: item[:text], actions: url_actions(item[:buttons]) }
    when 'card' then card_params
    else { template_type: 'twilio/text', body: content[:body] }
    end
  end

  def quick_reply_params
    buttons = content[:items].to_a.map { |i| { title: i[:title], id: i[:value].presence || i[:title] } }
    { template_type: 'twilio/quick-reply', body: content[:body], buttons: buttons }
  end

  def card_params
    {
      template_type: 'twilio/card',
      body: item[:description].presence || item[:title],
      title: item[:title],
      media_url: item[:media_url].presence,
      card_actions: url_actions(item[:actions])
    }
  end

  def url_actions(buttons)
    buttons.to_a.map { |b| { type: 'URL', title: b[:title] || b[:text], url: b[:uri] } }
  end
end
