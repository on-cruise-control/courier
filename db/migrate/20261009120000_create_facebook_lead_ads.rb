class CreateFacebookLeadAds < ActiveRecord::Migration[7.1]
  def change
    add_column :channel_facebook_pages, :page_name, :string
    create_lead_forms
    create_leads
  end

  private

  def create_lead_forms
    create_table :facebook_lead_forms do |t|
      t.references :account, null: false, index: true
      t.references :channel_facebook_page, null: false, index: false
      t.string :form_id, null: false
      t.string :name
      t.string :status
      t.string :locale
      t.jsonb :questions, null: false, default: []
      t.integer :leads_count, null: false, default: 0
      t.integer :meta_leads_count
      t.datetime :form_created_at
      t.datetime :last_synced_at
      t.timestamps
    end
    add_index :facebook_lead_forms, [:channel_facebook_page_id, :form_id], unique: true, name: 'index_facebook_lead_forms_on_page_and_form_id'
  end

  def create_leads
    create_table :facebook_leads do |t|
      t.references :account, null: false, index: true
      t.references :facebook_lead_form, null: false, index: false
      t.string :lead_id, null: false
      t.string :name
      t.string :email
      t.string :phone
      t.jsonb :field_data, null: false, default: []
      t.string :ad_id, :ad_name, :adset_id, :adset_name, :campaign_id, :campaign_name, :platform
      t.boolean :is_organic, null: false, default: false
      t.datetime :lead_created_at
      t.timestamps
    end
    add_index :facebook_leads, [:facebook_lead_form_id, :lead_id], unique: true
  end
end
