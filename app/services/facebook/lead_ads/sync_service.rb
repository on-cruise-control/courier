class Facebook::LeadAds::SyncService
  pattr_initialize [:channel!]

  def perform
    channel.update!(page_name: client.page_name)

    forms_from_graph.each do |form_data|
      form = channel.lead_forms.find_or_initialize_by(form_id: form_data['id'], account_id: channel.account_id)
      form.update_from_graph!(form_data)
    end
    channel.lead_forms.each { |form| sync_leads(form) }
    channel.broadcast_leads_changed
  end

  private

  def forms_from_graph
    client.lead_forms
  rescue Koala::Facebook::ClientError => e
    Rails.logger.warn "Lead forms listing failed for page #{channel.page_id}: #{e.message}"
    []
  end

  def sync_leads(form)
    since = form.leads.maximum(:lead_created_at)
    client.leads(form.form_id, since: since).each { |lead_data| form.save_lead_from_graph!(lead_data) }
    form.update!(last_synced_at: Time.current)
  end

  def client
    @client ||= Facebook::LeadAds::ApiClient.new(channel)
  end
end
