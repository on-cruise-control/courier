class ContentAttributeValidator < ActiveModel::Validator
  ALLOWED_SELECT_ITEM_KEYS = [:title, :value, :content_type].freeze
  ALLOWED_CARD_ITEM_KEYS = [:title, :description, :media_url, :actions, :vehicle_id, :default_action].freeze
  ALLOWED_CARD_ITEM_ACTION_KEYS = [:text, :type, :payload, :uri].freeze
  ALLOWED_FORM_ITEM_KEYS = [:type, :placeholder, :label, :name, :options, :default, :required, :pattern, :title, :pattern_error].freeze
  ALLOWED_ARTICLE_KEYS = [:title, :description, :link].freeze
  ALLOWED_CTA_ITEM_KEYS = [:text, :buttons].freeze
  ALLOWED_CTA_BUTTON_KEYS = [:type, :title, :payload, :uri].freeze

  def validate(record)
    case record.content_type
    when 'input_select'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_SELECT_ITEM_KEYS)
    when 'cards'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_CARD_ITEM_KEYS)
      validate_item_actions!(record)
    when 'form'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_FORM_ITEM_KEYS)
    when 'article'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_ARTICLE_KEYS)
    when 'call_to_action'
      validate_items!(record)
      validate_item_attributes!(record, ALLOWED_CTA_ITEM_KEYS)
      validate_item_buttons!(record)
    end
  end

  private

  def validate_items!(record)
    record.errors.add(:content_attributes, 'At least one item is required.') if record.items.blank?
    record.errors.add(:content_attributes, 'Items should be a hash.') if record.items.reject { |item| item.is_a?(Hash) }.present?
  end

  def validate_item_attributes!(record, valid_keys)
    item_keys = record.items.collect(&:keys).flatten.filter_map(&:to_sym)
    invalid_keys = item_keys - valid_keys
    record.errors.add(:content_attributes, "contains invalid keys for items : #{invalid_keys}") if invalid_keys.present?
  end

  def validate_item_actions!(record)
    item_action_keys = record.items.collect { |item| item[:actions].to_a.collect(&:keys) }
    invalid_keys = item_action_keys.flatten.compact.map(&:to_sym) - ALLOWED_CARD_ITEM_ACTION_KEYS
    record.errors.add(:content_attributes, "contains invalid keys for actions:  #{invalid_keys}") if invalid_keys.present?
  end

  def validate_item_buttons!(record)
    if record.items.select { |item| item[:buttons].blank? }.present?
      record.errors.add(:content_attributes, 'contains items missing buttons') && return
    end

    validate_item_button_attributes!(record)
  end

  def validate_item_button_attributes!(record)
    item_button_keys = record.items.collect { |item| item[:buttons].collect(&:keys) }
    invalid_keys = item_button_keys.flatten.compact.map(&:to_sym) - ALLOWED_CTA_BUTTON_KEYS
    record.errors.add(:content_attributes, "contains invalid keys for buttons: #{invalid_keys}") if invalid_keys.present?
  end
end
