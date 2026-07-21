class UserDailySessions::FinalizeService
  def initialize(account_user:, timestamp: Time.current, end_timestamp: nil)
    @account_user = account_user
    @timestamp = timestamp.in_time_zone
    @end_timestamp = end_timestamp&.in_time_zone
  end

  def perform
    account_user.with_lock do
      session = latest_session
      return unless session&.session_started_at.present?

      finished_at = end_timestamp || account_user.active_at || timestamp
      session.duration_seconds += [finished_at.to_i - session.session_started_at.to_i, 0].max
      session.session_started_at = nil
      session.save!
      session
    end
  end

  private

  attr_reader :account_user, :timestamp, :end_timestamp

  def latest_session
    UserDailySession.where(account_id: account_user.account_id, user_id: account_user.user_id).order(session_date: :desc, created_at: :desc).first
  end
end
