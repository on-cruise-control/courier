class RenameUserSessionsToUserDailySessions < ActiveRecord::Migration[7.1]
  def change
    if table_exists?(:user_sessions)
    rename_table :user_sessions, :user_daily_sessions

    rename_index :user_daily_sessions, 'index_user_sessions_on_account_user_and_session_date',
                 'index_user_daily_sessions_on_account_user_and_session_date'
    rename_index :user_daily_sessions, 'index_user_sessions_on_account_and_session_date',
                 'index_user_daily_sessions_on_account_and_session_date'
    rename_index :user_daily_sessions, 'index_user_sessions_on_user_and_session_date',
                 'index_user_daily_sessions_on_user_and_session_date'
    end
  end
end
