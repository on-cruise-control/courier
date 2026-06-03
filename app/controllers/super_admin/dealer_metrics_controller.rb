class SuperAdmin::DealerMetricsController < SuperAdmin::ApplicationController
  DEFAULT_RANGE_DAYS = 7
  DEFAULT_RANGE_KEY = 'last_7_days'.freeze
  RANGE_PRESETS = {
    'last_7_days' => 6,
    'last_14_days' => 13,
    'last_30_days' => 29,
    'last_90_days' => 89
  }.freeze
  SECTION_KEYS = %w[conversations spam bookings escalations handoffs agent_sessions].freeze

  def show
    if params[:page].blank? && request.format.html?
      redirect_to super_admin_dealer_metrics_url(default_redirect_params)
      return
    end

    service = SuperAdmin::DealerMetricsService.new(
      dealership_id: params[:dealership_id],
      account_id: params[:account_id],
      user_id: params[:user_id],
      range_key: normalized_range_key,
      since: parsed_since,
      until_time: parsed_until
    )

    filters = service.perform[:filters]
    section = if request.format.html? && current_page_key == 'bookings'
                {
                  key: 'bookings',
                  loading: true
                }
              else
                service.perform(section: current_page_key)
              end

    metrics = {
      filters: filters,
      section: section
    }

    respond_to do |format|
      format.html { @metrics = metrics }
      format.json { render json: metrics }
    end
  end

  private

  def default_redirect_params
    {
      page: SECTION_KEYS.first,
      dealership_id: params[:dealership_id].presence,
      range_key: normalized_range_key,
      since: params[:since].presence,
      until: params[:until].presence
    }.compact
  end

  def current_page_key
    requested_page = params[:page].presence || SECTION_KEYS.first
    SECTION_KEYS.include?(requested_page) ? requested_page : SECTION_KEYS.first
  end

  def normalized_range_key
    requested_range_key = params[:range_key].presence || DEFAULT_RANGE_KEY
    return requested_range_key if RANGE_PRESETS.key?(requested_range_key)

    'custom'
  end

  def parsed_since
    return RANGE_PRESETS[normalized_range_key].days.ago.to_date if RANGE_PRESETS.key?(normalized_range_key)

    Date.parse(params[:since])
  rescue StandardError
    DEFAULT_RANGE_DAYS.days.ago.to_date
  end

  def parsed_until
    return Time.zone.today if RANGE_PRESETS.key?(normalized_range_key)

    Date.parse(params[:until])
  rescue StandardError
    Time.zone.today
  end
end
