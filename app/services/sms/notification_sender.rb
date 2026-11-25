# Sends the SMS notifications (booking, escalation, handoff alerts) through the provider the account configured.
# An account has either a Twilio or a GoTo configuration, never both.
class Sms::NotificationSender
  pattr_initialize [:account!]

  def configured?
    goto&.configured? || twilio.present?
  end

  def deliver(to:, body:)
    return goto.send_message(to: to, body: body) if goto&.configured?

    twilio.client.messages.create(from: twilio.phone_number, to: to, body: body)
  end

  private

  def goto
    account.goto_configuration
  end

  def twilio
    account.twilio_configuration
  end
end
