class Goto::WebhookSetupService
  pattr_initialize [:channel!]

  def perform
    channel.update!(notification_channel_id: create_notification_channel)
    subscribe
  end

  private

  def create_notification_channel
    body = { channelType: 'Webhook', webhookChannelData: { webhook: { url: channel.webhook_url } } }
    response = request("#{Channel::GotoSms::API_URL}/notification-channel/v1/channels/courier-#{channel.id}", body)
    JSON.parse(response.body)['channelId']
  end

  def subscribe
    body = {
      accountKey: channel.account_key,
      ownerEntity: channel.account_key,
      ownerEntityType: 'ORGANIZATION',
      channelId: channel.notification_channel_id,
      eventTypes: %w[INBOUND_MESSAGE OUTBOUND_MESSAGE DELIVERY_STATUS]
    }
    request("#{Channel::GotoSms::API_URL}/messaging/v2/subscriptions", body)
  end

  def request(url, body)
    response = Faraday.post(url, body.to_json, 'Authorization' => "Bearer #{channel.access_token!}",
                                               'Content-Type' => 'application/json', 'Accept' => 'application/json')

    raise "GoTo POST #{url} failed (#{response.status}): #{response.body}" unless response.success?

    response
  end
end
