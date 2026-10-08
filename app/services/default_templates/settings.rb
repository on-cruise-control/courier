module DefaultTemplates::Settings
  KEYS = {
    auto_sync_on_inbox_create: 'DEFAULT_TEMPLATES_AUTO_SYNC_ON_INBOX_CREATE',
    auto_sync_on_template_change: 'DEFAULT_TEMPLATES_AUTO_SYNC_ON_TEMPLATE_CHANGE'
  }.freeze

  def self.enabled?(key)
    ActiveModel::Type::Boolean.new.cast(InstallationConfig.find_by(name: KEYS.fetch(key))&.value) || false
  end

  def self.update(values)
    turned_on = false
    KEYS.each do |key, config_name|
      next unless values.key?(key)

      turned_on ||= !enabled?(key) && ActiveModel::Type::Boolean.new.cast(values[key])
      config = InstallationConfig.find_or_initialize_by(name: config_name)
      config.value = ActiveModel::Type::Boolean.new.cast(values[key])
      config.save!
    end
    DefaultTemplates::SyncAllJob.perform_later if turned_on
  end

  def self.all
    KEYS.keys.index_with { |key| enabled?(key) }
  end
end
