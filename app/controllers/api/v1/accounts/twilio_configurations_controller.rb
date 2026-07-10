class Api::V1::Accounts::TwilioConfigurationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :set_twilio_configuration

  def show; end

  def create
    if @twilio_configuration.update(twilio_configuration_params)
      render :show
    else
      render json: { errors: @twilio_configuration.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @twilio_configuration.update(twilio_configuration_params)
      render :show
    else
      render json: { errors: @twilio_configuration.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @twilio_configuration.destroy!
    head :no_content
  end

  private

  def set_twilio_configuration
    @twilio_configuration = Current.account.twilio_configuration || Current.account.build_twilio_configuration
  end

  def twilio_configuration_params
    params.require(:twilio_configuration).permit(:account_sid, :auth_token, :phone_number)
  end

  def check_authorization
    authorize(AccountTwilioConfiguration)
  end
end
