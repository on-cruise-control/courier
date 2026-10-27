class Facebook::LeadAds::OutreachJob < ApplicationJob
  queue_as :default

  def perform(lead)
    Facebook::LeadAds::OutreachService.new(lead: lead).perform
    lead.facebook_lead_form.channel_facebook_page.broadcast_leads_changed(lead.facebook_lead_form_id)
  end
end
