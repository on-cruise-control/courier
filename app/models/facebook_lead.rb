# == Schema Information
#
# Table name: facebook_leads
#
#  id                    :bigint           not null, primary key
#  ad_name               :string
#  adset_name            :string
#  campaign_name         :string
#  email                 :string
#  field_data            :jsonb            not null
#  is_organic            :boolean          default(FALSE), not null
#  lead_created_at       :datetime
#  name                  :string
#  phone                 :string
#  platform              :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  ad_id                 :string
#  adset_id              :string
#  campaign_id           :string
#  facebook_lead_form_id :bigint           not null
#  lead_id               :string           not null
#
# Indexes
#
#  index_facebook_leads_on_account_id                         (account_id)
#  index_facebook_leads_on_facebook_lead_form_id_and_lead_id  (facebook_lead_form_id,lead_id) UNIQUE
#
class FacebookLead < ApplicationRecord
  belongs_to :account
  belongs_to :facebook_lead_form, counter_cache: :leads_count

  validates :lead_id, presence: true, uniqueness: { scope: :facebook_lead_form_id }

  def self.attributes_from_graph(data)
    answers = (data['field_data'] || []).to_h { |field| [field['name'], Array(field['values']).join(', ')] }
    full_name = answers['full_name'].presence || [answers['first_name'], answers['last_name']].compact_blank.join(' ')

    {
      name: full_name.presence,
      email: answers['email'],
      phone: answers['phone_number'],
      field_data: data['field_data'] || [],
      ad_id: data['ad_id'],
      ad_name: data['ad_name'],
      adset_id: data['adset_id'],
      adset_name: data['adset_name'],
      campaign_id: data['campaign_id'],
      campaign_name: data['campaign_name'],
      platform: data['platform'],
      is_organic: data['is_organic'] || false,
      lead_created_at: data['created_time']
    }
  end
end
