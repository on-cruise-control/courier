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

  def webhook_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/goto/webhooks/#{webhook_token}"
  end
end
