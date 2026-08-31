class AddAreaEscalationEmailsToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :sales_escalation_emails, :jsonb, default: []
    add_column :accounts, :service_escalation_emails, :jsonb, default: []
    add_column :accounts, :vehicle_parts_escalation_emails, :jsonb, default: []
  end
end
