# == Schema Information
#
# Table name: account_goto_configurations
#
#  id                      :bigint           not null, primary key
#  access_token            :text
#  access_token_expires_at :datetime
#  phone_number            :string
#  refresh_token           :text
#  account_key             :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#
# Indexes
#
#  index_account_goto_configurations_on_account_id  (account_id) UNIQUE
#
class AccountGotoConfiguration < ApplicationRecord
  include GotoAuthorizable

  belongs_to :account

  validates :account_id, uniqueness: true

  def configured?
    phone_number.present?
  end

  def connected?
    refresh_token.present?
  end
end
