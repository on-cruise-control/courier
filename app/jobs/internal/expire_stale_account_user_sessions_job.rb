class Internal::ExpireStaleAccountUserSessionsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AccountUser.includes(:user_sessions).find_each(batch_size: 100) do |account_user|
      latest_session = account_user.user_sessions.max_by { |session| [session.session_date, session.created_at] }
      next unless stale_session?(account_user, latest_session)

      UserSessions::FinalizeService.new(account_user: account_user).perform
    end
  end

  private

  def stale_session?(account_user, session)
    timeout_cutoff = AccountUser::SESSION_ACTIVE_TIMEOUT.ago

    return true if account_user.active_at.present? && account_user.active_at < timeout_cutoff
    return false if ::OnlineStatusTracker.get_presence(account_user.account_id, 'User', account_user.user_id)
    return true if session&.session_started_at.present? && session.session_started_at < timeout_cutoff

    false
  end
end
  