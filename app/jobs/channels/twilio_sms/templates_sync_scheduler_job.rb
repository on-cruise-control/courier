# frozen_string_literal: true

class Channels::TwilioSms::TemplatesSyncSchedulerJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Channel::TwilioSms.whatsapp
                      .where('content_templates_last_updated <= ? OR content_templates_last_updated IS NULL', 14.minutes.ago)
                      .each do |channel|
      Channels::TwilioSms::TemplatesSyncJob.perform_later(channel)
    end
  end
end
