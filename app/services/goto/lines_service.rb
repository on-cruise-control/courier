class Goto::LinesService
  pattr_initialize [:channel!]

  # "Get my GoTo Connect setup" is only used for the account key; the numbers come from Voice Admin,
  # filtered to the ones that are active and have texting enabled.
  def perform
    get!('/users/v1/me')['items'].flat_map do |item|
      sms_enabled_numbers(item['accountKey']).map { |number| { number: number, account_key: item['accountKey'] } }
    end
  end

  private

  def sms_enabled_numbers(account_key)
    get!("/voice-admin/v1/phone-numbers?accountKey=#{account_key}")['items'].filter_map do |item|
      phone = get!("/voice-admin/v1/phone-numbers/#{item['id']}")
      phone['number'] if phone['smsEnabled'] && phone['status'] == 'ACTIVE'
    end
  end

  def get!(path)
    response = Faraday.get("#{Channel::GotoSms::API_URL}#{path}", nil, 'Authorization' => "Bearer #{channel.access_token!}",
                                                                       'Accept' => 'application/json')
    raise "GoTo GET #{path} failed (#{response.status}): #{response.body}" unless response.success?

    JSON.parse(response.body)
  end
end
