class DefaultTemplates::SyncAllJob < ApplicationJob
  queue_as :low

  def perform
    Inbox.where(channel_type: %w[Channel::FacebookPage Channel::Instagram Channel::TwilioSms]).find_each do |inbox|
      DefaultTemplates::SyncJob.perform_later(inbox.id)
    end
  end
end
