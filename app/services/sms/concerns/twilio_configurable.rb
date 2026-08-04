module Sms::Concerns::TwilioConfigurable
  private

  def sms_config_enabled?
    twilio_configuration.present?
  end

  def twilio_configuration
    @twilio_configuration ||= @account.twilio_configuration
  end

  def twilio_account_sid
    twilio_configuration&.account_sid
  end

  def twilio_auth_token
    twilio_configuration&.auth_token
  end

  def organization_phone_number
    twilio_configuration&.phone_number
  end
end
