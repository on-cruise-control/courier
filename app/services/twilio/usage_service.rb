require 'net/http'
require 'uri'
require 'json'

class Twilio::UsageService
  TwilioUsageRecord = Struct.new(:category, :description, :count, :usage, :usage_unit,
                                 :price, :price_unit, :start_date, :end_date, keyword_init: true) do
    def self.from_hash(h)
      new(
        category: h['category'],
        description: h['description'],
        count: h['count'],
        usage: h['usage'],
        usage_unit: h['usage_unit'],
        price: h['price'],
        price_unit: h['price_unit'],
        start_date: h['start_date'],
        end_date: h['end_date']
      )
    end
  end
  SURCHARGE_PERCENT = 0.05

  CATEGORY_METADATA = {
    'channels' => { desc: 'Channels Platform', simple_desc: 'Messages sent through Twilio from your app or system.', unit: 'messages' },
    'channels-messaging' => { desc: 'Channels Platform', simple_desc: 'Messages sent through connected channels like WhatsApp or other chat apps.', unit: 'messages' },
    'channels-messaging-outbound' => { desc: 'Messaging Channels Outbound', simple_desc: 'Messages your team sent out to customers.', unit: 'messages' },
    'channels-messaging-inbound' => { desc: 'Messaging Channels Inbound', simple_desc: 'Messages customers sent back to you.', unit: 'messages' },
    'sms' => { desc: 'SMS', simple_desc: 'Regular text messages.', unit: 'segments' },
    'sms-outbound' => { desc: 'Outbound SMS', simple_desc: 'Text messages you sent to customers.', unit: 'segments' },
    'sms-inbound' => { desc: 'Inbound SMS', simple_desc: 'Text messages customers sent to you.', unit: 'segments' },
    'sms-outbound-longcode' => { desc: 'Standard Outbound SMS', simple_desc: 'Text messages you sent to customers.', unit: 'segments' },
    'sms-inbound-longcode' => { desc: 'Standard Inbound SMS', simple_desc: 'Text messages customers sent to you.', unit: 'segments' },
    'mms' => { desc: 'MMS', simple_desc: 'Messages with images, files, or other media.', unit: 'segments' },
    'mms-outbound' => { desc: 'Outbound MMS', simple_desc: 'Media messages you sent to customers.', unit: 'segments' },
    'mms-inbound' => { desc: 'Inbound MMS', simple_desc: 'Media messages customers sent to you.', unit: 'segments' },
    'mms-outbound-longcode' => { desc: 'Standard Outbound MMS', simple_desc: 'Media messages you sent to customers.', unit: 'segments' },
    'mms-inbound-longcode' => { desc: 'Standard Inbound MMS', simple_desc: 'Media messages customers sent to you.', unit: 'segments' },
    'a2p-registration-fees' => { desc: 'Messaging A2P Registration Fees', simple_desc: 'Fees for registering business texting in the US.', unit: 'usd' },
    'a2p-10dlc-registrationfees-monthly' => { desc: 'Registration Fees - Monthly Fees', simple_desc: 'Monthly fees to keep your campaign active.', unit: 'month' },
    'a2p-10dlc-registrationfees-campaigncharges' => { desc: 'Campaign Charges', simple_desc: 'Monthly fee for your approved campaign.', unit: 'month' },
    'a2p-10dlc-registrationfees-onetime' => { desc: 'Registration Fees - One-time Fees', simple_desc: 'One-time setup fees for business texting.', unit: 'once' },
    'a2p-10dlc-registrationfees-brandregistration' => { desc: 'Brand Registration', simple_desc: 'One-time fee to register your business.', unit: 'once' },
    'a2p-10dlc-registrationfees-campaignvetting' => { desc: 'Campaign Vetting', simple_desc: 'One-time fee to review and approve your texting campaign.', unit: 'once' },
    'mms-messages-carrierfees' => { desc: 'MMS Carrier Fees', simple_desc: 'Extra charges from carriers for media messages.', unit: 'messages' },
    'failed-message-processing-fee' => { desc: 'Failed Message Processing Fee', simple_desc: 'Small fee for messages that failed after processing.', unit: 'messages' },
    'sms-messages-carrierfees' => { desc: 'SMS Carrier Fees', simple_desc: 'Extra charges from carriers for text messages.', unit: 'segments' },
    'phonenumbers' => { desc: 'Phone Numbers', simple_desc: 'Monthly cost for the phone numbers you use.', unit: 'numbers' },
    'phonenumbers-local' => { desc: 'Local Phone Numbers', simple_desc: 'Monthly cost for the phone numbers you use.', unit: 'numbers' },
    'phonenumbers-setups' => { desc: 'Phone Number Setups', simple_desc: 'Monthly cost for the phone numbers you use.', unit: 'numbers' },
    'channels-root' => { desc: 'Channels', simple_desc: 'Overall messaging usage from connected channels.', unit: 'messages' },
    'channels-whatsapp' => { desc: 'WhatsApp', simple_desc: 'Messages sent or received on WhatsApp.', unit: 'messages' },
    'channels-whatsapp-template-service' => { desc: 'Channels - WhatsApp - Service', simple_desc: 'WhatsApp messages handled through the service.', unit: 'messages' },
    'channels-whatsapp-template-marketing' => { desc: 'Channels - WhatsApp - Template Marketing', simple_desc: 'WhatsApp marketing template messages sent to customers.', unit: 'messages' },
    'channels-whatsapp-template-utility' => { desc: 'Channels - WhatsApp - Template Utility', simple_desc: 'WhatsApp utility template messages sent to customers.', unit: 'messages' },
    'totalprice' => { desc: 'Total Price', simple_desc: 'The bill for all messages, fees, phone numbers, and other charges.', unit: 'usd' }
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
            },
            {
              id: 'sms-inbound',
              desc: 'Inbound SMS',
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
            },
            {
              id: 'mms-inbound',
              desc: 'Inbound MMS',
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
      id: 'phonenumbers',
      desc: 'Phone Numbers'
    },
    {
      id: 'channels-root',
      desc: 'Channels',
      children: [
        {
          id: 'channels-whatsapp',
          desc: 'WhatsApp',
          children: [
            { id: 'channels-whatsapp-template-marketing', desc: 'Channels - WhatsApp - Template Marketing' },
            { id: 'channels-whatsapp-template-utility', desc: 'Channels - WhatsApp - Template Utility' }
          ]
        }
      ]
    }
  ].freeze

  def initialize(account)
    @account = account
  end

  def usage(period: :this_month, api_version: 'v2')
    channel = twilio_channel
    return no_inbox_response unless channel

    period = :last_month if api_version == 'v1'

    client = build_client(channel)
    records = fetch_records(client, period)
    multiple_records_response(channel, records, api_version)
  rescue StandardError => e
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
    if channel.api_key_sid.present?
      { username: channel.api_key_sid, password: channel.auth_token, account_sid: channel.account_sid }
    else
      { username: channel.account_sid, password: channel.auth_token, account_sid: channel.account_sid }
    end
  end

  def fetch_records(client, period)
    account_sid = client[:account_sid]
    base_path = "/2010-04-01/Accounts/#{account_sid}/Usage/Records"

    path = case period.to_sym
           when :this_month then "#{base_path}/ThisMonth.json?PageSize=1000"
           when :last_month then "#{base_path}/LastMonth.json?PageSize=1000"
           when :today then "#{base_path}.json?PageSize=1000&StartDate=#{Date.current}&EndDate=#{Date.current}"
           when :yesterday then "#{base_path}.json?PageSize=1000&StartDate=#{Date.yesterday}&EndDate=#{Date.yesterday}"
           else "#{base_path}.json?PageSize=1000"
           end

    uri = URI("https://api.twilio.com#{path}")
    request = Net::HTTP::Get.new(uri)
    request.basic_auth(client[:username], client[:password])

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    raise StandardError, "Twilio API error: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    (parsed['usage_records'] || []).map { |r| TwilioUsageRecord.from_hash(r) }
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
      response[:categories] = HIERARCHY.map { |h| build_tree(h, category_map) }.compact

      twilio_total_price = response[:total_usage][:price].to_f
      stripe_fee = (twilio_total_price * SURCHARGE_PERCENT).round(4)
      
      response[:summary_categories] = []
      response[:summary_categories] << build_tree({ id: 'totalprice', desc: 'Total Price', is_summary: true }, category_map)

      if stripe_fee.positive?
        response[:summary_categories] << {
          category: 'stripe',
          description: 'Gateway charges',
          simple_desc: '5% platform charges.',
          count: 0,
          usage: nil,
          unit: '5%',
          price: stripe_fee,
          currency: 'USD',
          level: 0,
          is_summary: true,
          period: response[:total_usage][:period] || {}
        }
      end

      response[:total_usage][:price] = (twilio_total_price + stripe_fee).round(4)

      response[:summary_categories] << {
        category: 'grand-total',
        description: 'Grand Total',
        simple_desc: 'The total amount.',
        count: 0,
        usage: nil,
        unit: '',
        price: (twilio_total_price + stripe_fee).round(4),
        currency: 'USD',
        level: 0,
        is_summary: true,
        is_grand_total: true,
        period: response[:total_usage][:period] || {}
      }
    else
      twilio_total_price = response[:total_usage][:price].to_f
      stripe_fee = (twilio_total_price * SURCHARGE_PERCENT).round(4)

      total = response[:total_usage]
      response[:total_usage] = {
        category:        total[:category],
        description:     total[:description],
        count:           total[:count],
        usage:           total[:usage],
        unit:            total[:unit],
        price:           total[:price],
        gateway_charges: stripe_fee.round(4),
        total_cost:      (twilio_total_price + stripe_fee).round(4),
        currency:        total[:currency],
        period:          total[:period]
      }
    end

    response
  end

  def build_tree(item, category_map, level = 0)
    id = item.is_a?(String) ? item : item[:id]
    record = category_map[id]
    formatted = record ? format_record(record) : zero_record(id)
    formatted[:level] = level
    formatted[:is_summary] = item[:is_summary] if item.is_a?(Hash) && item[:is_summary]

    formatted[:description] = item[:desc] if item.is_a?(Hash) && item[:desc]
    formatted[:simple_desc] ||= item[:simple_desc] if item.is_a?(Hash) && item[:simple_desc]

    if item.is_a?(Hash) && item[:children].present?
      formatted[:children] = item[:children].map { |c| build_tree(c, category_map, level + 1) }.compact
      if formatted[:price].to_f == 0 && formatted[:count].to_i == 0
        formatted[:price] = formatted[:children].sum { |c| c[:price].to_f }.round(4)
        formatted[:count] = formatted[:children].sum { |c| c[:count].to_i }
      end
    end

    (formatted[:price].to_f != 0 || formatted[:count].to_i != 0 || formatted[:usage].to_i != 0 || formatted[:is_summary]) ? formatted : nil
  end

  def format_record(record)
    {
      category: record.category,
      description: record.description,
      simple_desc: CATEGORY_METADATA.dig(record.category, :simple_desc),
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
    meta = CATEGORY_METADATA[category] || { desc: category.titlecase, simple_desc: '', unit: 'count' }
    {
      category: category,
      description: meta[:desc],
      simple_desc: meta[:simple_desc],
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
