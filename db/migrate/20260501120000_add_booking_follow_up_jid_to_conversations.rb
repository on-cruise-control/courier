class AddBookingFollowUpJidToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :booking_follow_up_jid, :string
  end
end
