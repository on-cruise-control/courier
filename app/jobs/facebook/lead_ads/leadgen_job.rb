# Handles a `leadgen` webhook change: fetch the lead by id and store it under its form
class Facebook::LeadAds::LeadgenJob < ApplicationJob
  queue_as :default

  def perform(page_id, form_id, leadgen_id)
    Channel::FacebookPage.where(page_id: page_id).find_each do |channel|
      client = Facebook::LeadAds::ApiClient.new(channel)
      form = channel.lead_forms.find_or_initialize_by(form_id: form_id, account_id: channel.account_id)
      form.update_from_graph!(client.lead_form(form_id)) if form.new_record?
      form.save_lead_from_graph!(client.lead(leadgen_id))
      channel.broadcast_leads_changed(form.id)
    end
  end
end
