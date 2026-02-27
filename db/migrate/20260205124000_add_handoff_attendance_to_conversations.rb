class AddHandoffAttendanceToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :handoff_attended_at, :datetime
    add_column :conversations, :handoff_attended_by_id, :integer
    add_index :conversations, :handoff_attended_by_id
  end
end
