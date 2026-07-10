# == Schema Information
#
# Table name: account_twilio_configurations
#
#  id           :bigint           not null, primary key
#  account_sid  :string           not null
#  auth_token   :string           not null
#  phone_number :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_account_twilio_configurations_on_account_id  (account_id) UNIQUE
#
class AccountTwilioConfiguration < ApplicationRecord
  belongs_to :account

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  encrypts :auth_token if Chatwoot.encryption_configured?

  PHONE_NUMBER_FORMAT = /\A\+?\d{10,13}\z/

  validates :account_id, presence: true, uniqueness: true
  validates :account_sid, presence: true
  validates :auth_token, presence: true
  validates :phone_number, presence: true, format: { with: PHONE_NUMBER_FORMAT }

  def client
    Twilio::REST::Client.new(account_sid, auth_token)
  end
end
