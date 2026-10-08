# == Schema Information
#
# Table name: default_template_exclusions
#
#  id                  :bigint           not null, primary key
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  default_template_id :bigint           not null
#  inbox_id            :bigint           not null
#
# Indexes
#
#  index_default_template_exclusions_on_default_template_id  (default_template_id)
#  index_default_template_exclusions_unique                  (inbox_id,default_template_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (default_template_id => default_templates.id) ON DELETE => cascade
#  fk_rails_...  (inbox_id => inboxes.id) ON DELETE => cascade
#
class DefaultTemplateExclusion < ApplicationRecord
  belongs_to :inbox
  belongs_to :default_template
end
