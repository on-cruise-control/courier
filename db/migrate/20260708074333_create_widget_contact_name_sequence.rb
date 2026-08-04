class CreateWidgetContactNameSequence < ActiveRecord::Migration[7.1]
  def up
    execute 'CREATE SEQUENCE IF NOT EXISTS widget_contact_name_seq START 1'
  end

  def down
    execute 'DROP SEQUENCE IF EXISTS widget_contact_name_seq'
  end
end
