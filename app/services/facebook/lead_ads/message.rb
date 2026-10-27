# The first message sent to a lead, edited by the super admin and shared by every channel
module Facebook::LeadAds::Message
  CONFIG_NAME = 'FACEBOOK_LEAD_MESSAGE'.freeze
  VERSION_CONFIG_NAME = 'FACEBOOK_LEAD_MESSAGE_VERSION'.freeze
  ERRORS_CONFIG_NAME = 'FACEBOOK_LEAD_MESSAGE_ERRORS'.freeze

  def self.template
    InstallationConfig.find_by(name: CONFIG_NAME)&.value.presence || I18n.t('facebook_leads.outreach.default_message')
  end

  def self.update(text)
    changed = text != template
    config = InstallationConfig.find_or_initialize_by(name: CONFIG_NAME)
    config.value = text
    config.save!
    bump_version if changed
  end

  def self.whatsapp_template_name
    version = version_config.value.to_i
    version > 1 ? "lead_message_v#{version}" : 'lead_message'
  end

  def self.version_config
    InstallationConfig.find_or_initialize_by(name: VERSION_CONFIG_NAME).tap { |config| config.value ||= 1 }
  end

  def self.bump_version
    config = version_config
    config.value = config.value.to_i + 1
    config.save!
  end

  def self.submission_errors
    InstallationConfig.find_by(name: ERRORS_CONFIG_NAME)&.value || {}
  end

  def self.record_submission_error(inbox_id, error)
    config = InstallationConfig.find_or_initialize_by(name: ERRORS_CONFIG_NAME)
    errors = (config.value || {}).except(inbox_id.to_s)
    errors[inbox_id.to_s] = error if error
    config.value = errors
    config.save!
  end
end
