# frozen_string_literal: true

class Analytics::Ga4EventService
  include HTTParty
  base_uri 'https://www.google-analytics.com'
  default_timeout 5

  EVENT_OWNER = 'cruisecontrol'

  def initialize(account:, event_name:, client_id:, params: {})
    @account = account
    @event_name = event_name
    @client_id = client_id
    @params = params
    @measurement_id = Channel::WebWidget.where(account_id: account.id)
                                        .where.not(google_analytics_token: [nil, ''])
                                        .order(:id)
                                        .first&.google_analytics_token
    @api_secret = account.ga4_api_secret
  end

  def perform
    unless enabled?
      Rails.logger.info "--GA4 event skipped for account_id: #{@account.id} (missing measurement_id or api_secret)"
      return
    end

    response = self.class.post(
      '/mp/collect',
      query: { measurement_id: @measurement_id, api_secret: @api_secret },
      body: payload.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      Rails.logger.info "--GA4 event sent for account_id: #{@account.id}, event: #{@event_name}"
    else
      Rails.logger.error "--GA4 event failed for account_id: #{@account.id}: #{response.code} #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "--GA4 event exception for account_id: #{@account.id}: #{e.message}"
  end

  private

  def enabled?
    @measurement_id.present? && @api_secret.present?
  end

  def payload
    {
      client_id: @client_id,
      events: [{ name: @event_name, params: @params.merge(event_owner: EVENT_OWNER) }]
    }
  end
end
