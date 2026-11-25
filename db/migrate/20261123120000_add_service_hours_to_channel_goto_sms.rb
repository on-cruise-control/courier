class AddServiceHoursToChannelGotoSms < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_goto_sms, :service_hours, :jsonb
  end
end
