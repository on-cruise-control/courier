class Api::V1::Accounts::Channels::GotoChannelsController < Api::V1::Accounts::BaseController
  before_action :authorize_request
  before_action :set_channel, only: [:lines, :update]

  def authorization
    return render json: { error: 'GoTo is not configured' }, status: :unprocessable_entity if GlobalConfigService.load('GOTO_CLIENT_ID', nil).blank?

    channel = Current.account.goto_sms.where.missing(:inbox).first_or_create!
    state = Goto::CallbacksController.verifier.generate(['channel', channel.id], expires_in: 1.hour)
    render json: { url: channel.authorization_url(state, Goto::CallbacksController.redirect_uri) }
  end

  def lines
    render json: { lines: Goto::LinesService.new(channel: @channel).perform.map { |line| line.slice(:number, :name) } }
  rescue StandardError => e
    render_goto_error(e)
  end

  def update
    return render json: { error: 'phone_number_taken' }, status: :unprocessable_entity if number_taken?
    return render json: { error: 'name_taken' }, status: :unprocessable_entity if name_taken?

    ActiveRecord::Base.transaction do
      line = Goto::LinesService.new(channel: @channel).perform.find { |l| l[:number] == params[:phone_number] }
      @channel.update!(phone_number: line[:number], account_key: line[:account_key])
      inbox = Current.account.inboxes.create!(name: params[:name], channel: @channel)
      Goto::WebhookSetupService.new(channel: @channel).perform
      render json: { id: inbox.id }
    end
  rescue StandardError => e
    render_goto_error(e)
  end

  private

  def name_taken?
    Current.account.inboxes.exists?(['lower(name) = ?', params[:name].to_s.strip.downcase])
  end

  def number_taken?
    Channel::GotoSms.where.not(id: @channel.id).exists?(phone_number: params[:phone_number])
  end

  def render_goto_error(error)
    Rails.logger.error "[GOTO] #{error.message}"
    render_could_not_create_error(error.message)
  end

  def authorize_request
    authorize ::Inbox, :create?
  end

  # Channels without an inbox are authorized connections still waiting for a number to be picked.
  def set_channel
    @channel = Current.account.goto_sms.where.missing(:inbox).find(params[:id])
  end
end
