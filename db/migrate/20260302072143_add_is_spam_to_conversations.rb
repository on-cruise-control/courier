class AddIsSpamToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :is_spam, :boolean, default: false
    add_index :conversations, [:account_id, :is_spam]
  end
end
