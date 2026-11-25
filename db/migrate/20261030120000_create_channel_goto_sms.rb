class CreateChannelGotoSms < ActiveRecord::Migration[7.1]
  def change
    create_table :channel_goto_sms do |t|
      t.integer :account_id, null: false
      t.string :phone_number
      t.string :account_key
      t.text :refresh_token
      t.text :access_token
      t.datetime :access_token_expires_at
      t.string :notification_channel_id
      t.string :webhook_token, null: false
      t.timestamps
    end

    add_index :channel_goto_sms, :phone_number, unique: true
    add_index :channel_goto_sms, :webhook_token, unique: true
  end
end
