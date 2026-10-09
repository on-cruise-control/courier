# == Schema Information
#
# Table name: channel_facebook_pages
#
#  id                :integer          not null, primary key
#  content_templates :jsonb
#  facebook_page_url :string
#  page_access_token :text             not null
#  page_name         :string
#  user_access_token :text             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :integer          not null
#  instagram_id      :string
#  page_id           :string           not null
#
# Indexes
#
#  index_channel_facebook_pages_on_page_id                 (page_id)
#  index_channel_facebook_pages_on_page_id_and_account_id  (page_id,account_id) UNIQUE
#

class Channel::FacebookPage < ApplicationRecord
  include Channelable
  include Reauthorizable

  # TODO: Remove guard once encryption keys become mandatory (target 3-4 releases out).
  if Chatwoot.encryption_configured?
    encrypts :page_access_token
    encrypts :user_access_token
  end

  self.table_name = 'channel_facebook_pages'

  MESSENGER_FIELDS = %w[
    messages messaging_postbacks message_deliveries message_echoes message_reads standby messaging_handovers feed
  ].freeze

  has_many :lead_forms, class_name: 'FacebookLeadForm', foreign_key: :channel_facebook_page_id,
                        dependent: :destroy, inverse_of: :channel_facebook_page
  has_many :leads, through: :lead_forms

  validates :page_id, uniqueness: { scope: :account_id }

  before_save :ensure_facebook_page_url

  after_create_commit :subscribe
  before_destroy :unsubscribe

  def name
    'Facebook'
  end

  def create_contact_inbox(instagram_id, name)
    @contact_inbox = ::ContactInboxWithContactBuilder.new({
                                                            source_id: instagram_id,
                                                            inbox: inbox,
                                                            contact_attributes: { name: name }
                                                          }).perform
  end

  def subscribe
    # ref https://developers.facebook.com/docs/messenger-platform/reference/webhook-events
    # leadgen needs leads_retrieval; if the page token lacks it, keep the messenger fields working
    begin
      subscribe_fields(MESSENGER_FIELDS + %w[leadgen])
    rescue StandardError => e
      Rails.logger.warn "Leadgen subscription failed for page #{page_id}: #{e.message}"
      subscribe_fields(MESSENGER_FIELDS)
    end
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  # Tells open dashboards to reload their Leads pages
  def broadcast_leads_changed(form_id = nil)
    ActionCableBroadcastJob.perform_later(["account_#{account_id}"], 'facebook_lead.created', { account_id: account_id, form_id: form_id })
  end

  def unsubscribe
    Facebook::Messenger::Subscriptions.unsubscribe(access_token: page_access_token)
  rescue StandardError => e
    Rails.logger.debug { "Rescued: #{e.inspect}" }
    true
  end

  private

  def subscribe_fields(fields)
    Facebook::Messenger::Subscriptions.subscribe(access_token: page_access_token, subscribed_fields: fields)
  end

  def ensure_facebook_page_url
    return if facebook_page_url.present?

    self.facebook_page_url = "https://www.facebook.com/#{page_id}" if page_id.present?
  end
end
