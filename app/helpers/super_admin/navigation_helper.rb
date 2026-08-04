module SuperAdmin::NavigationHelper
  def settings_open?
    params[:controller].in? %w[super_admin/settings super_admin/app_configs]
  end

  def dealer_metrics_open?
    params[:controller] == 'super_admin/dealer_metrics'
  end

  def settings_pages
    features = SuperAdmin::FeaturesHelper.available_features.select do |_feature, attrs|
      attrs['config_key'].present? && attrs['enabled']
    end

    # Add general at the beginning
    general_feature = [['general', { 'config_key' => 'general', 'name' => 'General' }]]

    general_feature + features.to_a
  end

  def dealer_metrics_pages
    [
      ['conversations', { 'name' => 'Conversations' }],
      ['spam', { 'name' => 'Spam' }],
      ['bookings', { 'name' => 'Bookings' }],
      ['escalations', { 'name' => 'Escalations' }],
      ['handoffs', { 'name' => 'Handoffs' }],
      ['agent_sessions', { 'name' => 'Agent Sessions' }]
    ]
  end
end
