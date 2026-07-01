class RemoveLastSessionStartedAtFromUserSessions < ActiveRecord::Migration[7.1]
  def change
    if table_exists?(:user_sessions)
    remove_column :user_sessions, :last_session_started_at, :datetime
    end
  end
end
