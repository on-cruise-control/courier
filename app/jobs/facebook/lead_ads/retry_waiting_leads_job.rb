# Starts the conversation again for recent leads that were held back until WhatsApp approved the lead message
class Facebook::LeadAds::RetryWaitingLeadsJob < ApplicationJob
  queue_as :low

  WAITING_WINDOW = 7.days

  def perform(inbox)
    return unless inbox && Facebook::LeadAds::WhatsappTemplate.whatsapp_inboxes.include?(inbox)
    return unless Facebook::LeadAds::WhatsappTemplate.new(inbox: inbox).status == 'approved'

    waiting_leads(inbox).each { |lead| Facebook::LeadAds::OutreachJob.perform_later(lead) }
  end

  private

  def waiting_leads(inbox)
    FacebookLead.where(account_id: inbox.account_id, outreach_status: %w[needs_config partial], created_at: WAITING_WINDOW.ago..)
                .select { |lead| lead.outreach.any? { |result| result['channel'] == 'whatsapp' && result['status'] == 'needs_config' } }
  end
end
