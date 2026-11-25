class Api::V1::Accounts::GotoConfigurationsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def show
    render json: { connected: configuration&.connected? || false, configured: configuration&.configured? || false,
                   phone_number: configuration&.phone_number }
  end

  def authorization
    return render json: { error: 'GoTo is not configured' }, status: :unprocessable_entity if GlobalConfigService.load('GOTO_CLIENT_ID', nil).blank?

    record = Current.account.goto_configuration || Current.account.create_goto_configuration!
    state = Goto::CallbacksController.verifier.generate(['account', record.id], expires_in: 1.hour)
    render json: { url: record.authorization_url(state, Goto::CallbacksController.redirect_uri) }
  end

  def lines
    render json: { lines: Goto::LinesService.new(channel: configuration).perform.map { |line| line.slice(:number, :name) } }
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  # Choosing GoTo replaces the Twilio configuration.
  def update
    line = Goto::LinesService.new(channel: configuration).perform.find { |l| l[:number] == params[:phone_number] }
    ActiveRecord::Base.transaction do
      configuration.update!(phone_number: line[:number], account_key: line[:account_key])
      Current.account.twilio_configuration&.destroy!
    end
    render json: { configured: true, phone_number: configuration.phone_number }
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def destroy
    configuration&.destroy!
    head :no_content
  end

  private

  def configuration
    Current.account.goto_configuration
  end

  def check_authorization
    authorize(AccountGotoConfiguration)
  end
end
