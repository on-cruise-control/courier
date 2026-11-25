class Goto::DeliveryStatusService
  FAILED_CODE_START = 4000
  # Carriers often don't confirm MMS delivery. GoTo reports that as 5300, which is not a failure.
  UNCONFIRMED_CODE = 5300

  pattr_initialize [:channel!, :payload!]

  def perform
    return if message.blank?

    code = payload.dig(:deliveryStatus, :code).to_i
    if payload.dig(:deliveryStatus, :description) == 'DELIVERED'
      message.update!(status: :delivered)
    elsif code >= FAILED_CODE_START && code != UNCONFIRMED_CODE
      message.update!(status: :failed, external_error: "#{code} - #{payload.dig(:deliveryStatus, :description)}")
    end
  end

  private

  def message
    @message ||= channel.inbox.messages.find_by(source_id: payload[:messageId])
  end
end
