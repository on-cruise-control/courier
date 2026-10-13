class Api::V1::Accounts::Inboxes::DefaultTemplatesController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox
  before_action :check_admin_authorization?

  def sync
    return render json: { error: 'Default templates are not available for this inbox' }, status: :bad_request if platform.blank?

    unless DefaultTemplates::SyncService.new(inbox: @inbox).perform
      return render json: { error: 'A sync is already running for this inbox' },
                    status: :conflict
    end

    render json: { templates: @inbox.channel.reload.content_templates&.dig('templates') || [] }
  end

  private

  def platform
    DefaultTemplate.platform_for(@inbox)
  end

  def check_admin_authorization?
    return if current_user.is_a?(SuperAdmin)

    raise Pundit::NotAuthorizedError unless Current.account_user&.administrator?
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize @inbox, :show?
  end
end
