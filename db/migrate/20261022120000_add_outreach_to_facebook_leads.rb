class AddOutreachToFacebookLeads < ActiveRecord::Migration[7.1]
  def change
    add_column :facebook_leads, :outreach_status, :string, default: 'pending', null: false
    add_column :facebook_leads, :outreach, :jsonb, default: [], null: false
    add_reference :facebook_leads, :contact, index: true
  end
end
