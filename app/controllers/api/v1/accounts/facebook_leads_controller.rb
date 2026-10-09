class Api::V1::Accounts::FacebookLeadsController < Api::V1::Accounts::BaseController
  RESULTS_PER_PAGE = 15

  # Facebook pages the user can access, each with its lead forms
  def pages
    inboxes = facebook_inboxes.includes(channel: :lead_forms)
    render json: { pages: inboxes.map { |inbox| page_json(inbox) } }
  end

  def sync
    inboxes = params[:inbox_id].present? ? facebook_inboxes.where(id: params[:inbox_id]) : facebook_inboxes
    inboxes.each { |inbox| Facebook::LeadAds::SyncJob.perform_later(inbox.channel) }
    head :accepted
  end

  def index
    leads = filtered_leads.includes(facebook_lead_form: { channel_facebook_page: :inbox })
                          .order(lead_created_at: :desc)
                          .page(params[:page] || 1).per(RESULTS_PER_PAGE)
    render json: { payload: leads.map { |lead| lead_json(lead) }, meta: { count: leads.total_count, current_page: leads.current_page } }
  end

  private

  def facebook_inboxes
    Current.user.assigned_inboxes.where(channel_type: 'Channel::FacebookPage')
  end

  def filtered_leads
    channel_ids = facebook_inboxes.where(params[:inbox_id].present? ? { id: params[:inbox_id] } : {}).select(:channel_id)
    leads = FacebookLead.joins(:facebook_lead_form).where(facebook_lead_forms: { channel_facebook_page_id: channel_ids })
    leads = leads.where(facebook_lead_form_id: params[:form_id]) if params[:form_id].present?
    return leads if params[:q].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%"
    # field_data holds every answer, so custom questions (company, city, ...) are searchable too
    leads.where('facebook_leads.name ILIKE :q OR facebook_leads.field_data::text ILIKE :q', q: query)
  end

  def page_json(inbox)
    {
      inbox_id: inbox.id,
      inbox_name: inbox.name,
      page_id: inbox.channel.page_id,
      page_name: inbox.channel.page_name.presence || inbox.name,
      forms: inbox.channel.lead_forms.order(:name).as_json(except: [:account_id, :channel_facebook_page_id])
    }
  end

  def lead_json(lead)
    form = lead.facebook_lead_form
    channel = form.channel_facebook_page
    lead.as_json(except: [:account_id]).merge(
      form_name: form.name,
      inbox_id: channel.inbox.id,
      page_name: channel.page_name.presence || channel.inbox.name
    )
  end
end
