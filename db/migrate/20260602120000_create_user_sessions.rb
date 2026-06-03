class CreateUserSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :user_sessions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :session_date, null: false
      t.datetime :session_started_at
      t.datetime :last_session_started_at
      t.integer :duration_seconds, null: false, default: 0

      t.timestamps
    end

    add_index :user_sessions, [:account_id, :user_id, :session_date], unique: true, name: 'index_user_sessions_on_account_user_and_session_date'
    add_index :user_sessions, [:account_id, :session_date], name: 'index_user_sessions_on_account_and_session_date'
    add_index :user_sessions, [:user_id, :session_date], name: 'index_user_sessions_on_user_and_session_date'
  end
end
