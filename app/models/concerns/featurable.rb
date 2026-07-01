module Featurable
  extend ActiveSupport::Concern

  QUERY_MODE = {
    flag_query_mode: :bit_operator,
    check_for_column: false
  }.freeze

  MAX_FLAGS_PER_COLUMN = 63

  FEATURE_LIST = YAML.safe_load(Rails.root.join('config/features.yml').read).freeze

  FEATURES = FEATURE_LIST.each_with_object({}) do |feature, result|
    result[result.keys.size + 1] = "feature_#{feature['name']}".to_sym
  end

  FEATURES_COLUMN_1 = FEATURES.select { |k, _| k <= MAX_FLAGS_PER_COLUMN }.freeze
  FEATURES_COLUMN_2 = FEATURES.select { |k, _| k > MAX_FLAGS_PER_COLUMN }
                               .transform_keys { |k| k - MAX_FLAGS_PER_COLUMN }.freeze

  included do
    include FlagShihTzu
    has_flags FEATURES_COLUMN_1.merge(column: 'feature_flags').merge(QUERY_MODE)
    has_flags FEATURES_COLUMN_2.merge(column: 'feature_flags_2').merge(QUERY_MODE) if FEATURES_COLUMN_2.any?

    before_create :enable_default_features
  end

  def enable_features(*names)
    names.each do |name|
      send("feature_#{name}=", true)
    end
  end

  def enable_features!(*names)
    enable_features(*names)
    save
  end

  def disable_features(*names)
    names.each do |name|
      send("feature_#{name}=", false)
    end
  end

  def disable_features!(*names)
    disable_features(*names)
    save
  end

  def feature_enabled?(name)
    return false unless respond_to?("feature_#{name}?")

    send("feature_#{name}?")
  end

  def all_features
    FEATURE_LIST.pluck('name').index_with do |feature_name|
      feature_enabled?(feature_name)
    end
  end

  def enabled_features
    all_features.select { |_feature, enabled| enabled == true }
  end

  def disabled_features
    all_features.select { |_feature, enabled| enabled == false }
  end

  private

  def enable_default_features
    features_to_enable = FEATURE_LIST.select { |f| f['enabled'] }.pluck('name')
    enable_features(*features_to_enable)
  end
end
