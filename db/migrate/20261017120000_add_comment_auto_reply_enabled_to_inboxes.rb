class AddCommentAutoReplyEnabledToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :comment_auto_reply_enabled, :boolean, default: true, null: false
  end
end
