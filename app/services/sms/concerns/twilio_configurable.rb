module Sms::Concerns::TwilioConfigurable
  private

  def sms_config_enabled?
    notification_sender.configured?
  end

  def send_sms(to, body)
    notification_sender.deliver(to: to, body: body)
  end

  def notification_sender
    @notification_sender ||= Sms::NotificationSender.new(account: @account)
  end
end
