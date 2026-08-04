class UserSessions::RecordActivityService
  def initialize(account_user:, timestamp: Time.current)
    @account_user = account_user
    @timestamp = timestamp.in_time_zone
  end

  def perform
    account_user.with_lock do
      session = session_for_day

      if session.persisted? && stale_session?(session) && session.session_started_at.present?
        finalize_open_session!(session, account_user.active_at || timestamp)
      end

      start_session!(session) if session.new_record? || session.session_started_at.blank? || stale_session?(session)

      account_user.update!(active_at: timestamp)
      session.save! if session.changed?

      session
    end
  end

  private

  attr_reader :account_user, :timestamp

  def session_for_day
    UserDailySession.find_or_initialize_by(
      account_id: account_user.account_id,
      user_id: account_user.user_id,
      session_date: timestamp.to_date
    )
  end

  def stale_session?(session)
    account_user.active_at.blank? || account_user.active_at < timestamp - AccountUser::SESSION_ACTIVE_TIMEOUT
  end

  def start_session!(session)
    session.session_date = timestamp.to_date
    session.session_started_at = timestamp
    session.duration_seconds ||= 0
  end

  def finalize_open_session!(session, end_timestamp)
    session.duration_seconds += [end_timestamp.to_i - session.session_started_at.to_i, 0].max
    session.session_started_at = nil
  end
end
