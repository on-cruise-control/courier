class AddCommentEscalationEmailsToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :sales_comment_escalation_emails, :jsonb, default: []
    add_column :accounts, :service_comment_escalation_emails, :jsonb, default: []
    add_column :accounts, :vehicle_parts_comment_escalation_emails, :jsonb, default: []
  end
end
