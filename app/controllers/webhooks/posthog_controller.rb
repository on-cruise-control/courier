class Webhooks::PosthogController < ActionController::API
  LOG_TAG = '[PostHog Webhook]'.freeze

  before_action :verify_secret!

  SUPPORTED_FLAGS = { 'payment-calculator' => 'payment_calculator' }.freeze

  def events
    if params[:event] == 'flag_status_changed'
      handle_status_change
    else
      Rails.logger.info("#{LOG_TAG} ignored: unsupported event=#{params[:event].inspect}")
    end

    head :ok
  end

  private


  def handle_status_change
    flag_key = params[:flag_key]
    dealership_ids = params[:dealership_ids]
    active = ActiveModel::Type::Boolean.new.cast(params[:active])
    Rails.logger.info("#{LOG_TAG} received event=\"flag_status_changed\" flag=#{flag_key.inspect} active=#{active.inspect}")

    internal_flag = resolve_internal_flag(flag_key)
    return if internal_flag.nil?

    return Rails.logger.info("#{LOG_TAG} skipped: missing dealership_ids for flag=#{flag_key.inspect}") if dealership_ids.blank?

    reconcile_accounts(dealership_ids, internal_flag, active)
  end

  def reconcile_accounts(dealership_ids, internal_flag, active)
    desired_enabled_ids = active ? dealership_ids : []

    to_enable = Account.where(dealership_id: desired_enabled_ids).public_send("not_feature_#{internal_flag}")
    to_disable = Account.public_send("feature_#{internal_flag}").where.not(dealership_id: desired_enabled_ids)

    to_enable.find_each { |account| update_feature_flag(account, internal_flag, true) }
    to_disable.find_each { |account| update_feature_flag(account, internal_flag, false) }
  end

  def resolve_internal_flag(flag_key)
    internal_flag = SUPPORTED_FLAGS[flag_key]
    Rails.logger.info("#{LOG_TAG} skipped: unrecognized flag key=#{flag_key.inspect}") if internal_flag.nil?
    internal_flag
  end

  def update_feature_flag(account, internal_flag, enabled)
    enabled ? account.enable_features!(internal_flag) : account.disable_features!(internal_flag)
    Rails.logger.info("#{LOG_TAG} applied account_id=#{account.id} feature=#{internal_flag} enabled=#{enabled}")
  end

  def verify_secret!
    secret = GlobalConfigService.load('POSTHOG_WEBHOOK_SECRET', nil)
    return head :unauthorized if secret.blank?

    header_secret = request.headers['X-Posthog-Secret']
    return head :unauthorized if header_secret.blank?

    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(secret, header_secret)
  end
end
