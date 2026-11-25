# == Schema Information
#
# Table name: channel_goto_sms
#
#  id                      :bigint           not null, primary key
#  access_token            :text
#  access_token_expires_at :datetime
#  account_key             :string
#  phone_number            :string
#  refresh_token           :text
#  service_hours           :jsonb
#  webhook_token           :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :integer          not null
#  notification_channel_id :string
#
# Indexes
#
#  index_channel_goto_sms_on_phone_number   (phone_number) UNIQUE
#  index_channel_goto_sms_on_webhook_token  (webhook_token) UNIQUE
#

class Channel::GotoSms < ApplicationRecord
  include Channelable
  include GotoAuthorizable

  self.table_name = 'channel_goto_sms'

  EDITABLE_ATTRS = [].freeze

  has_secure_token :webhook_token

  validates :phone_number, uniqueness: true, allow_nil: true

  def name
    'GoTo SMS'
  end

  # True while the dealership's service department is open, i.e. agents are expected to reply instead of Stark.
  def service_hours_active?(time = Time.current)
    return false if service_hours.blank?

    local_time = time.in_time_zone(service_hours['timezone'])
    window = service_hours.dig('schedule', local_time.wday.to_s)
    return false if window.blank?

    open_minutes = minutes_of_day(window['open'])
    close_minutes = minutes_of_day(window['close']).nonzero? || (24 * 60)
    (open_minutes...close_minutes).cover?((local_time.hour * 60) + local_time.min)
  end

  # Opening time of the most recent service window at or before `time`.
  def last_service_open(time)
    local_time = time.in_time_zone(service_hours['timezone'])
    8.times do |days_back|
      date = local_time.to_date - days_back
      window = service_hours.dig('schedule', date.wday.to_s)
      next if window.blank?

      open_at = local_time.time_zone.local(date.year, date.month, date.day, *window['open'].split(':').map(&:to_i))
      return open_at if open_at <= time
    end
    nil
  end

  # Closing time of the most recent service window that has already ended at or before `time` (a 00:00 close is the end of that day).
  def last_service_close(time)
    local_time = time.in_time_zone(service_hours['timezone'])
    8.times do |days_back|
      date = local_time.to_date - days_back
      window = service_hours.dig('schedule', date.wday.to_s)
      next if window.blank?

      close_at = local_time.time_zone.local(date.year, date.month, date.day, *window['close'].split(':').map(&:to_i))
      close_at += 1.day if window['close'] <= window['open']
      return close_at if close_at <= time
    end
    nil
  end

  def webhook_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/goto/webhooks/#{webhook_token}"
  end

  private

  def minutes_of_day(time)
    hour, minute = time.split(':').map(&:to_i)
    (hour * 60) + minute
  end
end
