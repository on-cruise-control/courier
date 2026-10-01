class Meta::TemplateContentValidator
  BUTTON_TYPES = %w[web_url postback].freeze
  QUICK_REPLY_TYPES = %w[text user_phone_number user_email].freeze

  pattr_initialize :category, :content

  def errors
    return ['content is required'] if content.blank?

    case category
    when 'text' then validate_text
    when 'quick_reply' then validate_quick_reply
    when 'media' then validate_media
    when 'call_to_action' then validate_call_to_action
    when 'card' then validate_card
    else []
    end
  end

  private

  def validate_text
    content[:body].present? ? [] : ['body is required']
  end

  def validate_quick_reply
    errors = content[:body].present? ? [] : ['body is required']
    items = content[:items].to_a
    errors << 'at least one quick reply is required' if items.blank?
    errors << 'a maximum of 13 quick replies is allowed' if items.size > 13
    items.each { |item| errors.concat(validate_quick_reply_item(item)) }
    errors
  end

  def validate_quick_reply_item(item)
    content_type = item[:content_type].presence || 'text'
    errors = []
    errors << 'quick reply content type must be text, user_phone_number or user_email' unless QUICK_REPLY_TYPES.include?(content_type)
    errors << 'quick reply title is required' if item[:title].blank?
    errors
  end

  def validate_media
    errors = []
    errors << 'media_type is required' if content[:media_type].blank?
    errors << 'media_url is required' if content[:media_url].blank?
    errors
  end

  def validate_call_to_action
    item = content[:items].to_a.first
    return ['text is required'] if item.blank?

    errors = item[:text].present? ? [] : ['text is required']
    buttons = item[:buttons].to_a
    errors << 'at least one button is required' if buttons.blank?
    errors << 'a maximum of 3 buttons is allowed' if buttons.size > 3
    errors.concat(validate_buttons(buttons))
    errors
  end

  def validate_card
    items = content[:items].to_a
    errors = []
    errors << 'at least one card is required' if items.blank?
    errors << 'a maximum of 10 cards is allowed' if items.size > 10
    items.each { |item| errors.concat(validate_card_item(item)) }
    errors
  end

  def validate_card_item(item)
    errors = []
    errors << 'card title is required' if item[:title].blank?
    errors.concat(validate_buttons(item[:actions].to_a, max: 3)) if item[:actions].present?
    errors << 'default action requires a url' if item[:default_action].present? && item[:default_action][:url].blank?
    errors
  end

  def validate_buttons(buttons, max: 3)
    errors = []
    errors << "a maximum of #{max} buttons is allowed" if buttons.size > max
    buttons.each { |button| errors.concat(validate_button(button)) }
    errors
  end

  def validate_button(button)
    errors = []
    errors << 'button title is required' if (button[:title] || button[:text]).blank?
    errors.concat(validate_button_type(button))
    errors
  end

  def validate_button_type(button)
    return ['button type must be web_url or postback'] unless BUTTON_TYPES.include?(button[:type])

    required_field = button[:type] == 'web_url' ? :uri : :payload
    return ["#{button[:type]} button requires a #{required_field}"] if button[required_field].blank?

    []
  end
end
