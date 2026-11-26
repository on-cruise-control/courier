class Webhooks::GotoEventsJob < ApplicationJob
  queue_as :low

  def perform(webhook_token, params = {})
    channel = Channel::GotoSms.find_by(webhook_token: webhook_token)
    return if channel.blank?

    case params[:type]
    when 'call-state', 'REPORT_SUMMARY' then process_call_event(channel, params)
    when 'INBOUND_MESSAGE', 'OUTBOUND_MESSAGE' then process_message(channel, params.dig(:content, :payload))
    when 'DELIVERY_STATUS' then Goto::DeliveryStatusService.new(channel: channel, payload: params.dig(:content, :payload)).perform
    end
  end

  private

  def process_call_event(channel, params)
    Goto::CallEventService.new(channel: channel, params: params).perform
  rescue StandardError => e
    ChatwootExceptionTracker.new(e).capture_exception
  end

  # The GoTo subscription is org-wide, so every inbox's webhook receives all numbers' messages; keep only this inbox's number.
  def process_message(channel, payload)
    return unless payload[:channel] == 'SMS' && payload[:ownerTouchpoint] == channel.phone_number

    Goto::IncomingMessageService.new(channel: channel, payload: payload).perform
  end
end
