class AddNotificationEmailsToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :sales_representative_emails, :text, default: ''
  end
end
