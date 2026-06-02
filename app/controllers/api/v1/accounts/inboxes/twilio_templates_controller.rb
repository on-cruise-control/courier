class Api::V1::Accounts::Inboxes::TwilioTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_twilio_whatsapp_channel
  before_action :check_admin_authorization?, only: [:create, :update, :destroy, :submit_approval, :sync]

  TWILIO_TYPE_MAP = {
    'twilio/text' => 'text',
    'twilio/quick-reply' => 'quick_reply',
    'twilio/media' => 'media',
    'twilio/call-to-action' => 'call_to_action',
    'twilio/list-picker' => 'list_picker',
    'twilio/card' => 'card',
    'twilio/catalog' => 'catalog',
    'twilio/carousel' => 'carousel'
  }.freeze

  def index
    templates = @inbox.channel.content_templates&.dig('templates') || []
    render json: { templates: templates }
  end

  def create
    tp = template_params
    result = service.create_template(**tp)
    entry = build_cache_entry(result['sid'], tp)
    append_to_cache(entry)
    render json: { success: true, template: entry }, status: :created
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    tp = template_params
    result = service.update_template(params[:id], **tp)
    entry = build_cache_entry(result['sid'], tp)
    replace_in_cache(params[:id], entry)
    render json: { success: true, template: entry }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    service.delete_template(params[:id])
    remove_from_cache(params[:id])
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def sync
    Channels::TwilioSms::TemplatesSyncJob.perform_now(@inbox.channel)
    templates = @inbox.channel.reload.content_templates&.dig('templates') || []
    render json: { success: true, templates: templates }
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def submit_approval
    name = params[:name]
    category = params[:category] || 'UTILITY'
    samples = params[:variable_samples]&.permit!&.to_h&.transform_values(&:to_s)

    if samples.present?
      result = service.update_variables_and_submit(
        params[:id],
        variable_samples: samples,
        name: name,
        category: category
      )
      entry = rebuild_cache_from_twilio(result)
      replace_in_cache(params[:id], entry)
      render json: { success: true, new_content_sid: result['sid'] }
    else
      service.submit_for_whatsapp_approval(params[:id], name: name, category: category)
      render json: { success: true }
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def check_admin_authorization?
    return if current_user.is_a?(SuperAdmin)

    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end

  def validate_twilio_whatsapp_channel
    return if @inbox.channel_type == 'Channel::TwilioSms' && @inbox.channel.whatsapp?

    render json: { error: 'Template management is only available for Twilio WhatsApp inboxes' },
           status: :bad_request
  end

  def service
    @service ||= Twilio::TemplateManagementService.new(channel: @inbox.channel)
  end

  def rebuild_cache_from_twilio(result)
    twilio_type = result['types']&.keys&.first.to_s
    {
      content_sid: result['sid'],
      friendly_name: result['friendly_name'],
      language: result['language'],
      status: 'unsubmitted',
      template_type: TWILIO_TYPE_MAP[twilio_type] || 'text',
      body: result['types']&.values&.first&.dig('body'),
      variables: result['variables'] || {},
      created_at: result['date_created'],
      updated_at: result['date_updated']
    }
  end

  def build_cache_entry(sid, params)
    {
      content_sid: sid,
      friendly_name: params[:name],
      language: params[:language] || 'en',
      status: 'unsubmitted',
      template_type: TWILIO_TYPE_MAP[params[:template_type]] || 'text',
      body: params[:body],
      variables: params[:variables] || {},
      types: build_types_for_cache(params),
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def build_types_for_cache(params)
    type = params[:template_type] || 'twilio/text'
    body = params[:body] || ''
    case type
    when 'twilio/quick-reply'
      { type => { 'body' => body, 'actions' => (params[:buttons] || []).map { |b| { 'type' => 'QUICK_REPLY', 'title' => b[:title], 'id' => b[:id] } } } }
    when 'twilio/call-to-action'
      { type => { 'body' => body, 'actions' => (params[:actions] || []).map(&:stringify_keys) } }
    when 'twilio/card'
      payload = { 'body' => body }
      payload['title'] = params[:title] if params[:title].present?
      payload['media'] = [params[:media_url]] if params[:media_url].present?
      payload['actions'] = (params[:card_actions] || []).map(&:stringify_keys) if params[:card_actions].present?
      { type => payload }
    when 'twilio/list-picker'
      { type => { 'body' => body, 'button' => params[:list_button], 'items' => (params[:list_items] || []).map(&:stringify_keys) } }
    when 'twilio/media'
      payload = { 'body' => body }
      payload['media'] = [params[:media_url]] if params[:media_url].present?
      { type => payload }
    else
      { type => { 'body' => body } }
    end
  end

  def cached_templates
    @inbox.channel.content_templates&.dig('templates') || []
  end

  def persist_cache(templates)
    @inbox.channel.update!(
      content_templates: { templates: templates },
      content_templates_last_updated: Time.current
    )
  end

  def append_to_cache(entry)
    persist_cache(cached_templates + [entry])
  end

  def replace_in_cache(old_sid, entry)
    updated = cached_templates.reject { |t| t['content_sid'] == old_sid }
    persist_cache(updated + [entry])
  end

  def remove_from_cache(sid)
    persist_cache(cached_templates.reject { |t| t['content_sid'] == sid })
  end

  def template_params
    raw = params.require(:template).permit(
      :name, :body, :template_type, :language, :media_url, :title, :list_button,
      variables: {},
      buttons: [:title, :id],
      actions: [:type, :title, :url, :phone],
      card_actions: [:type, :title, :id, :url, :phone, :code],
      list_items: [:id, :title, :description]
    )
    {
      name: raw[:name],
      body: raw[:body],
      template_type: raw[:template_type] || 'twilio/text',
      language: raw[:language] || 'en',
      variables: raw[:variables] || {},
      buttons: (raw[:buttons] || []).map(&:to_h).map(&:symbolize_keys),
      actions: (raw[:actions] || []).map(&:to_h).map(&:symbolize_keys),
      card_actions: (raw[:card_actions] || []).map(&:to_h).map(&:symbolize_keys),
      media_url: raw[:media_url],
      title: raw[:title],
      list_button: raw[:list_button] || 'Select',
      list_items: (raw[:list_items] || []).map(&:to_h).map(&:symbolize_keys)
    }
  end
end
