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
    existing = existing_conversation_ids(leads)
    render json: { payload: leads.map { |lead| lead_json(lead, existing) }, meta: { count: leads.total_count, current_page: leads.current_page } }
  end

  def show
    lead = leads_scope.includes(facebook_lead_form: { channel_facebook_page: :inbox }).find(params[:id])
    render json: lead_json(lead, existing_conversation_ids([lead])).merge(questions: lead.facebook_lead_form.questions)
  end

  def outreach
    lead = leads_scope.find(params[:id])
    Facebook::LeadAds::OutreachService.new(lead: lead).perform
    render json: lead_json(lead, existing_conversation_ids([lead]))
  end

  private

  def leads_scope
    channel_ids = facebook_inboxes.select(:channel_id)
    FacebookLead.joins(:facebook_lead_form).where(facebook_lead_forms: { channel_facebook_page_id: channel_ids })
  end

  def facebook_inboxes
    Current.user.assigned_inboxes.where(channel_type: 'Channel::FacebookPage')
  end

  def filtered_leads
    leads = leads_scope
    if params[:inbox_id].present?
      leads = leads.where(facebook_lead_forms: { channel_facebook_page_id: facebook_inboxes.where(id: params[:inbox_id]).select(:channel_id) })
    end
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

  def existing_conversation_ids(leads)
    ids = leads.flat_map { |lead| lead.outreach.pluck('conversation_id') }.compact
    Conversation.where(account_id: Current.account.id, display_id: ids).pluck(:display_id)
  end

  def lead_json(lead, existing_conversation_ids)
    form = lead.facebook_lead_form
    channel = form.channel_facebook_page
    outreach = lead.outreach.map do |result|
      existing_conversation_ids.include?(result['conversation_id']) ? result : result.merge('conversation_id' => nil)
    end
    lead.as_json(except: [:account_id, :contact_id]).merge(
      outreach: outreach,
      form_id: form.id,
      form_name: form.name,
      inbox_id: channel.inbox.id,
      page_name: channel.page_name.presence || channel.inbox.name
    )
  end
end
