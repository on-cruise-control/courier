class AddAiInServiceHoursToChannelGotoSms < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_goto_sms, :ai_in_service_hours, :boolean, default: false, null: false
  end
end
