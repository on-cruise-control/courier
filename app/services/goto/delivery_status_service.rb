class Goto::DeliveryStatusService
  DELIVERED_CODE = 1000
  FAILED_CODE_START = 4000

  pattr_initialize [:channel!, :payload!]

  def perform
    return if message.blank?

    code = payload.dig(:deliveryStatus, :code).to_i
    if code == DELIVERED_CODE
      message.update!(status: :delivered)
    elsif code >= FAILED_CODE_START
      message.update!(status: :failed, external_error: "#{code} - #{payload.dig(:deliveryStatus, :description)}")
    end
  end

  private

  def message
    @message ||= channel.inbox.messages.find_by(source_id: payload[:messageId])
  end
end
