class AddIsBlacklistedToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :is_blacklisted, :boolean, default: false
    add_index :conversations, [:account_id, :is_blacklisted]
  end
end
