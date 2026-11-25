class Dealership::ServiceHoursService
  include HTTParty

  DAYS = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze
  DEFAULT_TIMEZONE = 'America/New_York'.freeze

  def initialize(account)
    @account = account
    @base_url = GlobalConfig.get('DEALERSHIP_API_BASE_URL')['DEALERSHIP_API_BASE_URL']
    @api_key = GlobalConfig.get('DEALERSHIP_API_KEY')['DEALERSHIP_API_KEY']
  end

  def perform
    response = self.class.get("#{@base_url}/api/v1/dealerships/#{@account.dealership_id}",
                              headers: { 'Authorization' => "Bearer #{@api_key}" })
    raise "Dealership API responded with #{response.code}" unless response.success?

    data = response.parsed_response.dig('body', 'data')
    { timezone: timezone_from(data['timezone']), schedule: schedule_from(data['hours']) }
  end

  private

  def schedule_from(hours)
    hours.to_a.each_with_object({}) do |hour, schedule|
      day = DAYS.index(hour['day_of_week'])
      next if day.nil? || hour['service_open_time'].blank? || hour['service_close_time'].blank?

      schedule[day.to_s] = { open: hour['service_open_time'][0, 5], close: hour['service_close_time'][0, 5] }
    end
  end

  def timezone_from(timezone)
    TZInfo::Timezone.all_identifiers.include?(timezone) ? timezone : DEFAULT_TIMEZONE
  end
end
