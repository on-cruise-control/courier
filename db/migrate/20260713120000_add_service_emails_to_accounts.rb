class AddServiceEmailsToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :service_emails, :jsonb, default: []
  end
end
