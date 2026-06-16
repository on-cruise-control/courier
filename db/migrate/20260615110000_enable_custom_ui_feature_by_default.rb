class EnableCustomUiFeatureByDefault < ActiveRecord::Migration[7.0]
  def up
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return unless config

    features = config.value.map do |feature|
      feature['name'] == 'custom_ui' ? feature.merge('enabled' => true) : feature
    end
    config.update!(value: features)
  end

  def down
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return unless config

    features = config.value.map do |feature|
      feature['name'] == 'custom_ui' ? feature.merge('enabled' => false) : feature
    end
    config.update!(value: features)
  end
end
