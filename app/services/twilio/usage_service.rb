class Twilio::UsageService
  CATEGORIES = %w[
    channels
    channels-messaging-outbound
    channels-messaging-inbound
    sms
    sms-outbound-longcode
    sms-inbound-longcode
    mms
    mms-outbound-longcode
    mms-inbound-longcode
    a2p-10dlc-registrationfees-monthly
    a2p-10dlc-registrationfees-campaigncharges
    a2p-10dlc-registrationfees-onetime
    a2p-10dlc-registrationfees-brandregistration
    a2p-10dlc-registrationfees-campaignvetting
    mms-messages-carrierfees
    failed-message-processing-fee
    sms-messages-carrierfees
    phonenumbers
    phonenumbers-local
    phonenumbers-setups
    channels-whatsapp-template-service
    totalprice
  ].freeze

  CATEGORY_METADATA = {
    'channels' => { desc: 'Channels Platform', unit: 'messages' },
    'channels-messaging-outbound' => { desc: 'Messaging Channels Outbound', unit: 'messages' },
    'channels-messaging-inbound' => { desc: 'Messaging Channels Inbound', unit: 'messages' },
    'sms' => { desc: 'SMS', unit: 'segments' },
    'sms-outbound-longcode' => { desc: 'Standard Outbound SMS', unit: 'segments' },
    'sms-inbound-longcode' => { desc: 'Standard Inbound SMS', unit: 'segments' },
    'mms' => { desc: 'MMS', unit: 'segments' },
    'mms-outbound-longcode' => { desc: 'Standard Outbound MMS', unit: 'segments' },
    'mms-inbound-longcode' => { desc: 'Standard Inbound MMS', unit: 'segments' },
    'a2p-10dlc-registrationfees-monthly' => { desc: 'Registration Fees - Monthly Fees', unit: 'month' },
    'a2p-10dlc-registrationfees-campaigncharges' => { desc: 'Campaign Charges', unit: 'month' },
    'a2p-10dlc-registrationfees-onetime' => { desc: 'Registration Fees - One-time Fees', unit: 'once' },
    'a2p-10dlc-registrationfees-brandregistration' => { desc: 'Brand Registration', unit: 'once' },
    'a2p-10dlc-registrationfees-campaignvetting' => { desc: 'Campaign Vetting', unit: 'once' },
    'mms-messages-carrierfees' => { desc: 'MMS Carrier Fees', unit: 'messages' },
    'failed-message-processing-fee' => { desc: 'Failed Message Processing Fee', unit: 'messages' },
    'sms-messages-carrierfees' => { desc: 'SMS Carrier Fees', unit: 'segments' },
    'phonenumbers' => { desc: 'Phone Numbers', unit: 'numbers' },
    'phonenumbers-local' => { desc: 'Local Phone Numbers', unit: 'numbers' },
    'phonenumbers-setups' => { desc: 'Phone Number Setups', unit: 'numbers' },
    'channels-whatsapp-template-service' => { desc: 'Channels - WhatsApp - Service', unit: 'messages' },
    'totalprice' => { desc: 'Total Price', unit: 'usd' }
  }.freeze

  HIERARCHY = [
    {
      id: 'channels',
      desc: 'Programmable Messaging',
      children: [
        {
          id: 'channels-messaging',
          desc: 'Channels Platform',
          children: ['channels-messaging-outbound', 'channels-messaging-inbound']
        },
        {
          id: 'sms',
          desc: 'SMS',
          children: [
            {
              id: 'sms-outbound',
              desc: 'Outbound SMS',
              children: ['sms-outbound-longcode']
            },
            {
              id: 'sms-inbound',
              desc: 'Inbound SMS',
              children: ['sms-inbound-longcode']
            },
          ]
        },
        {
          id: 'mms',                                                                        
          desc: 'MMS',
          children: [
            {
              id: 'mms-outbound',
              desc: 'Outbound MMS',
              children: ['mms-outbound-longcode']
            },
            {
              id: 'mms-inbound',
              desc: 'Inbound MMS',
              children: ['mms-inbound-longcode']
            }
          ]
        },
        {
          id: 'a2p-registration-fees',
          desc: 'Messaging A2P Registration Fees',
          children: [
            {
              id: 'a2p-10dlc-registrationfees-onetime',
              desc: 'Registration Fees - One-time Fees',
              children: [
                {
                  id: 'a2p-10dlc-registrationfees-brandregistration',
                  desc: 'Brand Registration'
                },
                {
                  id: 'a2p-10dlc-registrationfees-campaignvetting',
                  desc: 'Campaign Vetting'
                }
              ]
            },
            {
              id: 'a2p-10dlc-registrationfees-monthly',
              desc: 'Registration Fees - Monthly Fees',
              children: [
                {
                  id: 'a2p-10dlc-registrationfees-campaigncharges',
                  desc: 'Campaign Charges'
                }
              ]
            }
          ]
        },
        'mms-messages-carrierfees',
        'failed-message-processing-fee',
        'sms-messages-carrierfees'
      ]
    },
    {
      id: 'phonenumbers-root',
      desc: 'Phone Numbers',
      children: [
        'phonenumbers-setups',
        {
          id: 'phonenumbers',
          desc: 'Phone Numbers',
          children: ['phonenumbers-local']
        }
      ]
    },
    {
      id: 'channels-root',
      desc: 'Channels',
      children: [
        {
          id: 'channels-whatsapp',
          desc: 'WhatsApp',
          children: ['channels-whatsapp-template-service']
        }
      ]
    }
  ].freeze

  def initialize(account)
    @account = account
  end

  # Fetch usage for a given period.
  def usage(period: :this_month, api_version: 'v2')
    channel = twilio_channel
    return no_inbox_response unless channel

    period = :last_month if api_version == 'v1'

    client = build_client(channel)
    records = fetch_records(client, period)
    multiple_records_response(channel, records, api_version)
  rescue Twilio::REST::RestError => e
    error_response(e.message)
  end

  private

  def twilio_channel
    @account.twilio_sms.first
  end

  def no_inbox_response
    {
      success: true,
      message: 'No Twilio SMS inbox found for this account',
      dealership_id: @account.dealership_id,
      inbox: nil,
      usage: nil
    }
  end

  def build_client(channel)
    Twilio::REST::Client.new(channel.account_sid, channel.auth_token)
  end

  def fetch_records(client, period)
    params = {}
    case period.to_sym
    when :this_month
      client.usage.records.this_month.list(**params)
    when :last_month
      client.usage.records.last_month.list(**params)
    when :today
      params[:start_date] = Date.current.to_s
      params[:end_date] = Date.current.to_s
      client.usage.records.list(**params)
    when :yesterday
      params[:start_date] = Date.yesterday.to_s
      params[:end_date] = Date.yesterday.to_s
      client.usage.records.list(**params)
    else
      client.usage.records.list(**params)
    end
  end

  def multiple_records_response(channel, records, api_version)
    total_record = records.find { |r| r.category == 'totalprice' }

    response = {
      success: true,
      dealership_id: @account.dealership_id,
      total_usage: total_record ? format_record(total_record) : zero_record('totalprice')
    }

    if api_version == 'v2'
      category_map = records.index_by(&:category)
      response[:categories] = HIERARCHY.map { |h| build_tree(h, category_map) }
    end

    response
  end

  def build_tree(item, category_map, level = 0)
    id = item.is_a?(String) ? item : item[:id]
    record = category_map[id]
    formatted = record ? format_record(record) : zero_record(id)
    formatted[:level] = level

    formatted[:description] = item[:desc] if item.is_a?(Hash) && item[:desc]

    if item.is_a?(Hash) && item[:children].present?
      formatted[:children] = item[:children].map { |c| build_tree(c, category_map, level + 1) }
      # Roll up totals if price/count are zero but children have values
      if formatted[:price].to_f == 0 && formatted[:count].to_i == 0
        formatted[:price] = formatted[:children].sum { |c| c[:price].to_f }.round(4)
        formatted[:count] = formatted[:children].sum { |c| c[:count].to_i }
      end
    end

    formatted
  end

  def format_record(record)
    {
      category: record.category,
      description: record.description,
      count: record.count.to_i,
      usage: record.usage.to_i,
      unit: record.usage_unit,
      price: record.price.to_f.round(4),
      currency: record.price_unit&.upcase,
      period: {
        start_date: record.start_date,
        end_date: record.end_date
      }
    }
  end

  def zero_record(category)
    meta = CATEGORY_METADATA[category] || { desc: category.titleize, unit: 'count' }
    {
      category: category,
      description: meta[:desc],
      count: 0,
      usage: 0,
      unit: meta[:unit],
      price: 0.0,
      currency: 'USD',
      period: {}
    }
  end

  def error_response(message)
    { success: false, error: message, dealership_id: @account.dealership_id }
  end
end
