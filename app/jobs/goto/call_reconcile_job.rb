# Started only by a call webhook: if the final report never arrives, fetch it from GoTo until the call is reported.
class Goto::CallReconcileJob < ApplicationJob
  queue_as :low

  rescue_from(StandardError) { |error| ChatwootExceptionTracker.new(error).capture_exception }

  INTERVAL = 2.minutes
  MAX_ATTEMPTS = 30

  def perform(channel_id, call_id, attempt = 1)
    channel = Channel::GotoSms.find(channel_id)
    message = Goto::CallEventService.find_message(channel.inbox, call_id)
    return if message.blank? || message.content_attributes.dig('data', 'reported')

    report = fetch_report(channel, call_id)
    if report
      Goto::CallEventService.new(channel: channel, params: { type: 'REPORT_SUMMARY', content: report }).perform
    elsif attempt < MAX_ATTEMPTS
      self.class.set(wait: INTERVAL).perform_later(channel_id, call_id, attempt + 1)
    else
      Goto::CallEventService.new(channel: channel, params: {}).finalize_stale(message)
    end
  end

  private

  def fetch_report(channel, call_id)
    response = Faraday.get("#{Channel::GotoSms::API_URL}/call-events-report/v1/reports/#{call_id}", nil,
                           'Authorization' => "Bearer #{channel.access_token!}")
    JSON.parse(response.body).deep_symbolize_keys if response.success?
  end
end
