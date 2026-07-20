class SuperAdmin::DealerAgentPresenceService
  SESSION_STATE_ACTIVE = 'active'.freeze
  SESSION_STATE_EXPIRED = 'expired'.freeze
  SESSION_STATE_NO_ACTIVITY = 'no_activity'.freeze

  def initialize(accounts:)
    @accounts = accounts
  end

  def perform
    {
      total_users: all_users.size,
      total_active_user_sessions: active_users.size,
      total_inactive_user_sessions: inactive_users.size,
      total_users_by_account: count_by_account(all_users),
      active_user_sessions_by_account: count_by_account(active_users),
      inactive_user_sessions_by_account: count_by_account(inactive_users),
      all_users: sorted_users
    }
  end

  private

  attr_reader :accounts

  def all_users
    @all_users ||= accounts.flat_map do |account|
      account.account_users.includes(:user).map do |account_user|
        build_user_payload(account, account_user)
      end
    end
  end

  def sorted_users
    all_users.sort_by do |user|
      [
        user[:session_state] == 'active' ? 0 : 1,
        -(user[:sort_active_at] || 0),
        user[:dealership_name].to_s
      ]
    end
  end

  def active_users
    @active_users ||= all_users.select { |user| user[:session_state] == 'active' }
  end

  def inactive_users
    @inactive_users ||= all_users.reject { |user| user[:session_state] == 'active' }
  end

  def count_by_account(users)
    users.each_with_object(Hash.new(0)) do |user, counts|
      counts[user[:account_id]] += 1
    end
  end

  def build_user_payload(account, account_user)
    session = latest_session_for(account_user)
    active_session = live_session?(account_user, session)
    session = finalize_stale_session(account_user, session) if session&.session_started_at.present? && !active_session
    active_at = account_user.active_at&.to_i
    session_duration_seconds = session_duration_for(session, active_session)
    session_started_at = session_started_at_for(session, active_session)

    {
      account_id: account.id,
      dealership_id: account.dealership_id,
      dealership_name: account.name,
      user_id: account_user.user_id,
      user_name: account_user.user.name,
      user_email: account_user.user.email,
      sort_active_at: active_at,
      session_state: session_state(session, active_session),
      session_started_at: timestamp_to_iso8601(active_session ? session_started_at : nil),
      session_duration_seconds: session_duration_seconds
    }
  end

  def latest_session_for(account_user)
    UserDailySession.where(account_id: account_user.account_id, user_id: account_user.user_id)
                    .order(session_date: :desc, created_at: :desc)
                    .first
  end

  def session_duration_for(session, _active_session)
    return session&.duration_seconds if session.present?

    nil
  end

  def session_started_at_for(session, active_session)
    return session&.session_started_at if active_session

    nil
  end

  def session_state(session, active_session)
    return SESSION_STATE_ACTIVE if active_session
    return SESSION_STATE_EXPIRED if session.present?

    SESSION_STATE_NO_ACTIVITY
  end

  def finalize_stale_session(account_user, session)
    UserDailySessions::FinalizeService.new(
      account_user: account_user,
      timestamp: Time.current,
      end_timestamp: account_user.active_at
    ).perform
    latest_session_for(account_user) || session
  end

  def live_session?(account_user, session)
    return false unless session&.session_started_at.present?

    now = Time.current
    timeout_cutoff = now - AccountUser::SESSION_ACTIVE_TIMEOUT

    return true if account_user.active_at.present? && account_user.active_at >= timeout_cutoff
    return true if redis_user_present?(account_user)
    return true if session.session_started_at >= timeout_cutoff

    false
  end

  def redis_user_present?(account_user)
    ::OnlineStatusTracker.get_presence(account_user.account_id, 'User', account_user.user_id)
  end

  def timestamp_to_iso8601(timestamp)
    return if timestamp.blank?

    timestamp.iso8601
  end
end
