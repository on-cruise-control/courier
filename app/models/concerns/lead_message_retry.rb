# Leads waiting on WhatsApp's review of the lead message are retried once a template sync brings the approval
module LeadMessageRetry
  extend ActiveSupport::Concern

  included do
    after_update_commit :retry_waiting_leads, if: -> { saved_changes.key?('content_templates') || saved_changes.key?('message_templates') }
  end

  private

  def retry_waiting_leads
    Facebook::LeadAds::RetryWaitingLeadsJob.perform_later(inbox)
  end
end
