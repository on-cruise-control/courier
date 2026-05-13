# frozen_string_literal: true

class Channels::TwilioSms::TemplatesSyncJob < ApplicationJob
  queue_as :low

  def perform(channel)
    Twilio::TemplateSyncService.new(channel: channel).call
  end
end
