class AddVehiclePartsEmailsToAccounts < ActiveRecord::Migration[7.0]
  def change
    add_column :accounts, :vehicle_parts_emails, :jsonb, default: []
  end
end
