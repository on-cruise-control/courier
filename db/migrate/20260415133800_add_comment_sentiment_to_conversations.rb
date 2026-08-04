class AddCommentSentimentToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :comment_sentiment, :string
  end
end
