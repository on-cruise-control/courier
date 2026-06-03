class RemoveLastSessionStartedAtFromUserSessions < ActiveRecord::Migration[7.1]
  def change
    remove_column :user_sessions, :last_session_started_at, :datetime
  end
end
