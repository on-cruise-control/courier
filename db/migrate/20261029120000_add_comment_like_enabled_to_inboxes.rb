class AddCommentLikeEnabledToInboxes < ActiveRecord::Migration[7.1]
  def change
    add_column :inboxes, :comment_like_enabled, :boolean, default: false, null: false
  end
end
