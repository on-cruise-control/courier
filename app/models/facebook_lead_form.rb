# == Schema Information
#
# Table name: facebook_lead_forms
#
#  id                       :bigint           not null, primary key
#  form_created_at          :datetime
#  last_synced_at           :datetime
#  leads_count              :integer          default(0), not null
#  locale                   :string
#  meta_leads_count         :integer
#  name                     :string
#  questions                :jsonb            not null
#  status                   :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  account_id               :bigint           not null
#  channel_facebook_page_id :bigint           not null
#  form_id                  :string           not null
#
# Indexes
#
#  index_facebook_lead_forms_on_account_id        (account_id)
#  index_facebook_lead_forms_on_page_and_form_id  (channel_facebook_page_id,form_id) UNIQUE
#
class FacebookLeadForm < ApplicationRecord
  belongs_to :account
  belongs_to :channel_facebook_page, class_name: 'Channel::FacebookPage'
  has_many :leads, class_name: 'FacebookLead', dependent: :delete_all

  validates :form_id, presence: true, uniqueness: { scope: :channel_facebook_page_id }

  def update_from_graph!(data)
    update!(
      name: data['name'],
      status: data['status'],
      locale: data['locale'],
      meta_leads_count: data['leads_count'],
      questions: data['questions'] || [],
      form_created_at: data['created_time']
    )
  end

  def save_lead_from_graph!(data)
    lead = leads.find_or_initialize_by(lead_id: data['id'])
    lead.update!(FacebookLead.attributes_from_graph(data).merge(account_id: account_id))
    lead
  end
end
