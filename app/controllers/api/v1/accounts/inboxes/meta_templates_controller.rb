class Api::V1::Accounts::Inboxes::MetaTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :validate_meta_channel
  before_action :check_admin_authorization?, only: [:create, :update, :destroy]

  CATEGORIES = %w[text quick_reply media call_to_action card].freeze

  class TemplateValidationError < StandardError; end

  def index
    render json: { templates: cached_templates }
  end

  def create
    entry = build_entry(template_params)
    persist_cache(cached_templates + [entry])
    render json: { template: entry }, status: :created
  rescue TemplateValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    entry = build_entry(template_params, id: params[:id])
    updated = cached_templates.map { |t| t['id'] == params[:id] ? entry : t }
    persist_cache(updated)
    render json: { template: entry }
  rescue TemplateValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    persist_cache(cached_templates.reject { |t| t['id'] == params[:id] })
    head :ok
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

  def validate_meta_channel
    return if @inbox.channel_type.in?(%w[Channel::FacebookPage Channel::Instagram])

    render json: { error: 'Template management is only available for Facebook and Instagram inboxes' },
           status: :bad_request
  end

  def cached_templates
    @inbox.channel.content_templates&.dig('templates') || []
  end

  def persist_cache(templates)
    @inbox.channel.update!(content_templates: { templates: templates })
  end

  def build_entry(attrs, id: nil)
    attrs = attrs.to_h.with_indifferent_access
    validate_template!(attrs)
    {
      id: id || SecureRandom.uuid,
      name: attrs[:name],
      category: attrs[:category],
      content: attrs[:content],
      updated_at: Time.current
    }.stringify_keys
  end

  def validate_template!(attrs)
    errors = []
    errors << 'name is required' if attrs[:name].blank?
    errors << 'invalid category' unless CATEGORIES.include?(attrs[:category])
    errors.concat(Meta::TemplateContentValidator.new(attrs[:category], attrs[:content]).errors)
    raise TemplateValidationError, errors.join(', ') if errors.any?
  end

  def template_params
    params.require(:template).permit(
      :name, :category,
      content: [:body, :text, :media_type, :media_url, :caption,
                { items: [:title, :value, :content_type, :text, :description, :media_url,
                          { actions: [:text, :type, :payload, :uri],
                            buttons: [:type, :title, :payload, :uri],
                            default_action: [:type, :url] }] }]
    )
  end
end
