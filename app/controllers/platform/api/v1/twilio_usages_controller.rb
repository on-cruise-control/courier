class Platform::Api::V1::TwilioUsagesController < PlatformController
  skip_before_action :validate_platform_app_permissible
  before_action :set_resource

  # GET /platform/api/v1/dealership/:dealership_id/twilio_usage
  def show
    result = ::Twilio::UsageService.new(@resource).usage(api_version: 'v1')

    if result[:success]
      render json: result, status: :ok
    else
      render json: { error: result[:error] || result[:message] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def set_resource
    @resource = Account.find_by!(dealership_id: params[:dealership_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Dealership not found' }, status: :not_found
  end
end
