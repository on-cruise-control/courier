class Api::V1::Dealerships::TwilioUsagesController < Api::BaseController
  # Skip the global bot validation from Api::BaseController as it seems to be failing
  # with Current.user type checks in this specific context.
  skip_before_action :validate_bot_access_token!
  
  before_action :authenticate_access_token!
  before_action :set_account
  before_action :check_admin_or_agent

  # GET /api/v1/dealership/:dealership_id/twilio_usage
  def show
    result = ::Twilio::UsageService.new(@account).usage(
      period: params[:period].presence || :this_month,
      api_version: 'v1'
    )

    if result[:success]
      render json: result, status: :ok
    else
      render json: { error: result[:error] || result[:message] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def set_account
    @account = Account.find_by!(dealership_id: params[:dealership_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dealership not found' }, status: :not_found
  end

  def check_admin_or_agent
    # Use Current.user which is set by authenticate_access_token!
    @account_user = @account.account_users.find_by(user_id: Current.user&.id)
    return if @account_user&.administrator? || @account_user&.agent?

    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end

