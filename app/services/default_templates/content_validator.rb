class DefaultTemplates::ContentValidator
  # WhatsApp (Twilio) is stricter than Messenger/Instagram, so templates shared with it follow its limits.
  STRICT_PLATFORMS = %w[all whatsapp].freeze
  MAX_BODY = 1024
  MAX_QUICK_REPLIES = 3
  MAX_QUICK_REPLY_TITLE = 20
  MAX_BUTTONS = 2
  MAX_BUTTON_TITLE = 25
  MAX_CARDS = 1

  pattr_initialize :platform, :category, :content

  def errors
    data = content.to_h.with_indifferent_access
    messages = Meta::TemplateContentValidator.new(category, data).errors
    messages.concat(strict_errors(data)) if platform.in?(STRICT_PLATFORMS)
    messages.uniq
  end

  private

  def strict_errors(data)
    case category
    when 'text' then body_errors(data[:body])
    when 'quick_reply' then quick_reply_errors(data)
    when 'media' then media_errors(data)
    when 'call_to_action' then cta_errors(data)
    when 'card' then card_errors(data)
    else []
    end
  end

  def body_errors(body)
    body.to_s.length > MAX_BODY ? ["body must be at most #{MAX_BODY} characters"] : []
  end

  def quick_reply_errors(data)
    items = data[:items].to_a
    messages = body_errors(data[:body])
    messages << "a maximum of #{MAX_QUICK_REPLIES} quick replies is allowed for #{platform}" if items.size > MAX_QUICK_REPLIES
    messages << 'only text quick replies are allowed' if items.any? { |item| item[:content_type].presence.to_s.in?(%w[user_phone_number user_email]) }
    messages << "quick reply titles must be at most #{MAX_QUICK_REPLY_TITLE} characters" if items.any? do |i|
      i[:title].to_s.length > MAX_QUICK_REPLY_TITLE
    end
    messages
  end

  def media_errors(data)
    data[:caption].to_s.length > MAX_BODY ? ["caption must be at most #{MAX_BODY} characters"] : []
  end

  def cta_errors(data)
    item = data[:items].to_a.first || {}
    messages = body_errors(item[:text])
    buttons = item[:buttons].to_a
    messages << "a maximum of #{MAX_BUTTONS} buttons is allowed for #{platform}" if buttons.size > MAX_BUTTONS
    messages.concat(button_errors(buttons))
  end

  def card_errors(data)
    items = data[:items].to_a
    messages = []
    messages << "a maximum of #{MAX_CARDS} card is allowed for #{platform}" if items.size > MAX_CARDS
    items.each do |item|
      actions = item[:actions].to_a
      messages << "a maximum of #{MAX_BUTTONS} buttons is allowed for #{platform}" if actions.size > MAX_BUTTONS
      messages.concat(button_errors(actions))
    end
    messages
  end

  def button_errors(buttons)
    messages = []
    messages << 'only web_url buttons are allowed' if buttons.any? { |b| b[:type] != 'web_url' }
    messages << "button titles must be at most #{MAX_BUTTON_TITLE} characters" if buttons.any? do |b|
      (b[:title] || b[:text]).to_s.length > MAX_BUTTON_TITLE
    end
    messages
  end
end
