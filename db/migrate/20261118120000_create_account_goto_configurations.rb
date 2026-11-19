class CreateAccountGotoConfigurations < ActiveRecord::Migration[7.1]
  def change
    create_table :account_goto_configurations do |t|
      t.bigint :account_id, null: false
      t.string :phone_number
      t.string :account_key
      t.text :refresh_token
      t.text :access_token
      t.datetime :access_token_expires_at
      t.timestamps
    end

    add_index :account_goto_configurations, :account_id, unique: true
  end
end
