# The widget_contact_name_seq sequence is created via a raw SQL `execute` in
# db/migrate/20260708074333_create_widget_contact_name_sequence.rb. Raw SQL
# isn't captured in db/schema.rb, so `db:schema:load` (used to build the test
# database) marks that migration as applied without ever running it, leaving
# the sequence missing in CI. Ensure it exists before specs run.
RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection.execute('CREATE SEQUENCE IF NOT EXISTS widget_contact_name_seq START 1')
  end
end
