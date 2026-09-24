# frozen_string_literal: true

class Analytics::CommTypeResolver
  RESOLVERS = {
    'instagram' => ->(inbox) { inbox.instagram? },
    'facebook' => ->(inbox) { inbox.facebook? },
    'whatsapp' => ->(inbox) { inbox.whatsapp? || inbox.twilio_whatsapp? },
    'sms' => ->(inbox) { inbox.sms? || (inbox.twilio? && !inbox.twilio_whatsapp?) },
    'widget' => ->(inbox) { inbox.web_widget? },
    'email' => ->(inbox) { inbox.email? },
    'telegram' => ->(inbox) { inbox.telegram? },
    'tiktok' => ->(inbox) { inbox.tiktok? },
    'twitter' => ->(inbox) { inbox.twitter? },
    'line' => ->(inbox) { inbox.channel_type == 'Channel::Line' },
    'api' => ->(inbox) { inbox.api? }
  }.freeze

  def self.for(inbox)
    return if inbox.blank?

    RESOLVERS.find { |_label, matcher| matcher.call(inbox) }&.first
  end
end
