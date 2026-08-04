class AddEscalationEmailsToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :escalation_emails, :jsonb, default: []
  end
end
