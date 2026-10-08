class DefaultTemplates::SyncJob < ApplicationJob
  queue_as :low

  def perform(inbox_id)
    inbox = Inbox.find_by(id: inbox_id)
    return unless inbox

    self.class.set(wait: 30.seconds).perform_later(inbox_id) unless DefaultTemplates::SyncService.new(inbox: inbox).perform
  end
end
