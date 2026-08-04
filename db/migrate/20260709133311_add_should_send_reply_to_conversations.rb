class AddShouldSendReplyToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :should_send_reply, :boolean, default: true
  end
end
