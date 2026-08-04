class CreateAccountTwilioConfigurations < ActiveRecord::Migration[7.0]
  def change
    create_table :account_twilio_configurations do |t|
      t.references :account, null: false, index: { unique: true }
      t.string :account_sid, null: false
      t.string :auth_token, null: false
      t.string :phone_number, null: false

      t.timestamps
    end
  end
end
