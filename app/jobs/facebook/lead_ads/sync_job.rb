class Facebook::LeadAds::SyncJob < ApplicationJob
  queue_as :default

  def perform(channel)
    Facebook::LeadAds::SyncService.new(channel: channel).perform
  end
end
