# == Schema Information
#
# Table name: user_daily_sessions
#
#  id                 :bigint           not null, primary key
#  duration_seconds   :integer          default(0), not null
#  session_date       :date             not null
#  session_started_at :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_user_daily_sessions_on_account_and_session_date       (account_id,session_date)
#  index_user_daily_sessions_on_account_id                     (account_id)
#  index_user_daily_sessions_on_account_user_and_session_date  (account_id,user_id,session_date) UNIQUE
#  index_user_daily_sessions_on_user_and_session_date          (user_id,session_date)
#  index_user_daily_sessions_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#

class UserDailySession < ApplicationRecord
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
