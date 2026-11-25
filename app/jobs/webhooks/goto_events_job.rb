class Webhooks::GotoEventsJob < ApplicationJob
  queue_as :low

  def perform(webhook_token, params = {})
    channel = Channel::GotoSms.find_by(webhook_token: webhook_token)
    payload = params.dig(:content, :payload)
    return if channel.blank? || payload.blank?

    case params[:type]
    when 'INBOUND_MESSAGE', 'OUTBOUND_MESSAGE' then process_message(channel, payload)
    when 'DELIVERY_STATUS' then Goto::DeliveryStatusService.new(channel: channel, payload: payload).perform
    end
  end

  private

  # The GoTo subscription is org-wide, so every inbox's webhook receives all numbers' messages; keep only this inbox's number.
  def process_message(channel, payload)
    return unless payload[:channel] == 'SMS' && payload[:ownerTouchpoint] == channel.phone_number

    Goto::IncomingMessageService.new(channel: channel, payload: payload).perform
  end
end
