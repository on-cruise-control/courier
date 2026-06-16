# == Schema Information
#
# Table name: user_sessions
#
#  id                     :bigint           not null, primary key
#  account_id             :bigint           not null
#  user_id                :bigint           not null
#  session_date           :date             not null
#  session_started_at     :datetime
#  duration_seconds       :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

class UserSession < ApplicationRecord
  belongs_to :account
  belongs_to :user

  validates :session_date, presence: true
  validates :duration_seconds, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: [:account_id, :session_date] }

  def live_duration_seconds(timestamp = Time.current)
    return duration_seconds if session_started_at.blank?

    duration_seconds + [timestamp.to_i - session_started_at.to_i, 0].max
  end
end
