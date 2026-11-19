class Goto::CallbacksController < ApplicationController
  def show
    type, id = self.class.verifier.verify(params[:state])
    record = type == 'account' ? AccountGotoConfiguration.find(id) : Channel::GotoSms.find(id)
    record.authorize!(params[:code], self.class.redirect_uri)

    redirect_to "#{request.base_url}#{type == 'account' ? account_settings_path(record) : inbox_setup_path(record)}"
  rescue StandardError => e
    Rails.logger.error "[GOTO] OAuth callback failed: #{e.message}"
    redirect_to "#{request.base_url}/app/login?error=goto_connect_failed"
  end

  def self.verifier
    Rails.application.message_verifier(:goto_oauth)
  end

  def self.redirect_uri
    "#{ENV.fetch('FRONTEND_URL', nil)}/goto/callback"
  end

  private

  def account_settings_path(record)
    "/app/accounts/#{record.account_id}/settings/general?goto_connected=1"
  end

  def inbox_setup_path(channel)
    "/app/accounts/#{channel.account_id}/settings/inboxes/new/sms?goto_channel=#{channel.id}"
  end
end
