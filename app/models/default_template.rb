# == Schema Information
#
# Table name: default_templates
#
#  id         :bigint           not null, primary key
#  category   :string           not null
#  content    :jsonb            not null
#  language   :string           default("en"), not null
#  name       :string           not null
#  platform   :string           default("all"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_default_templates_on_name_and_platform  (name,platform) UNIQUE
#
class DefaultTemplate < ApplicationRecord
  PLATFORMS = %w[all whatsapp facebook instagram].freeze
  CATEGORIES = %w[text quick_reply media call_to_action card].freeze
  ENTRY_MARKERS = %w[default_template_id is_default default_version locally_modified].freeze

  has_many :default_template_exclusions, dependent: :delete_all

  validates :name, presence: true, uniqueness: { scope: :platform }, format: { with: /\A[a-z0-9_]+\z/, allow_blank: true }
  validates :platform, inclusion: { in: PLATFORMS }
  validates :category, inclusion: { in: CATEGORIES }
  validates :language, presence: true
  before_validation :normalize_card_actions, if: -> { category == 'card' }
  validate :platform_unchanged, on: :update
  validate :content_matches_platform_rules

  after_commit :sync_inboxes

  # Links an inbox template entry to this default (see ENTRY_MARKERS).
  def entry_markers
    { 'default_template_id' => id, 'is_default' => true, 'default_version' => updated_at.iso8601(6) }
  end

  def self.platform_for(inbox)
    case inbox.channel_type
    when 'Channel::FacebookPage' then 'facebook'
    when 'Channel::Instagram' then 'instagram'
    when 'Channel::TwilioSms' then 'whatsapp' if inbox.channel.whatsapp?
    end
  end

  private

  # Messages only accept text/type/payload/uri on card actions, so `title` is folded into `text`.
  def normalize_card_actions
    return if content['items'].blank?

    items = content['items'].map do |item|
      actions = item['actions'].to_a.map { |action| action.except('title').merge('text' => action['text'].presence || action['title']) }
      item.merge('actions' => actions)
    end
    self.content = content.merge('items' => items)
  end

  def platform_unchanged
    errors.add(:platform, 'cannot be changed') if platform_changed?
  end

  def content_matches_platform_rules
    return unless category.in?(CATEGORIES) && platform.in?(PLATFORMS)

    DefaultTemplates::ContentValidator.new(platform, category, content).errors.each { |message| errors.add(:content, message) }
  end

  def sync_inboxes
    DefaultTemplates::SyncAllJob.perform_later if DefaultTemplates::Settings.enabled?(:auto_sync_on_template_change)
  end
end
