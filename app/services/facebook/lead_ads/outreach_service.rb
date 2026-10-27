# Starts a conversation with a lead on every channel (email, sms, whatsapp) that has an active inbox.
# Per-channel results are kept on the lead so the UI can show a status and retry what did not go through.
class Facebook::LeadAds::OutreachService
  CHANNELS = %w[email sms whatsapp].freeze

  pattr_initialize [:lead!]

  def perform
    results = sent_results + CHANNELS.reject { |channel| already_sent?(channel) }.map { |channel| outreach_channel(channel) }
    lead.update!(contact: contact, outreach: results, outreach_status: overall_status(results))
    lead
  rescue StandardError => e
    lead.update!(outreach: [{ 'status' => 'failed', 'error' => e.message }], outreach_status: 'failed')
    lead
  end

  private

  delegate :account, to: :lead

  def sent_results
    lead.outreach.select { |result| result['status'] == 'sent' }
  end

  def already_sent?(channel)
    sent_results.any? { |result| result['channel'] == channel }
  end

  def outreach_channel(channel)
    return result(channel, 'skipped', error: missing_address_error(channel)) if address(channel).blank?

    inbox = candidate_inboxes(channel).first
    return result(channel, 'skipped', error: I18n.t('facebook_leads.outreach.no_inbox', channel: channel)) unless inbox

    start_conversation(channel, inbox)
  end

  def missing_address_error(channel)
    I18n.t("facebook_leads.outreach.#{channel == 'email' ? 'no_email' : 'no_phone'}")
  end

  def address(channel)
    case channel
    when 'email' then lead.email.presence
    when 'whatsapp' then whatsapp_phone
    else normalized_phone
    end
  end

  # Meta sends numbers like "p:+919876543210"
  def normalize_phone(raw)
    digits = raw.to_s.gsub(/\D/, '')
    "+#{digits}" if digits.present?
  end

  def normalized_phone
    normalize_phone(lead.phone)
  end

  # WhatsApp uses the form's WhatsApp number, and the phone number when the form has none
  def whatsapp_phone
    normalize_phone(lead.whatsapp_number) || normalized_phone
  end

  # An inbox that is disconnected and waiting to be reauthorized is not active
  def candidate_inboxes(channel)
    account.inboxes.order(:id).select { |inbox| inbox_channel(inbox) == channel && !inbox.channel.try(:reauthorization_required?) }
  end

  # Twilio inboxes carry either SMS or WhatsApp, depending on their medium
  def inbox_channel(inbox)
    case inbox.channel_type
    when 'Channel::Email' then 'email'
    when 'Channel::Sms' then 'sms'
    when 'Channel::Whatsapp' then 'whatsapp'
    when 'Channel::TwilioSms' then inbox.channel.medium
    end
  end

  def start_conversation(channel, inbox)
    @template_params = nil
    error = whatsapp_error(inbox) if channel == 'whatsapp'
    return result(channel, 'needs_config', inbox: inbox, error: error, address: address(channel)) if error

    conversation = create_conversation(channel, inbox)
    send_message(conversation)
    result(channel, 'sent', inbox: inbox, conversation: conversation, address: address(channel))
  rescue StandardError => e
    result(channel, 'failed', inbox: inbox, error: e.message, address: address(channel))
  end

  # WhatsApp only starts a conversation with a template that WhatsApp has approved
  def whatsapp_error(inbox)
    template = Facebook::LeadAds::WhatsappTemplate.new(inbox: inbox)
    status = template.ready_status
    @template_params = template.template_params if status == 'approved'
    return if status == 'approved'

    I18n.t("facebook_leads.outreach.whatsapp_#{status}", error: template.error)
  rescue StandardError => e
    I18n.t('facebook_leads.outreach.whatsapp_missing', error: e.message)
  end

  def create_conversation(channel, inbox)
    contact_inbox = ContactInboxBuilder.new(contact: contact, inbox: inbox, source_id: source_id_for(channel, inbox)).perform
    Conversation.create!(
      account_id: account.id, inbox_id: inbox.id, contact_id: contact.id, contact_inbox_id: contact_inbox.id,
      additional_attributes: { 'facebook_lead' => { 'id' => lead.id, 'form_id' => lead.facebook_lead_form_id, 'channel' => channel } }
    )
  end

  def source_id_for(channel, inbox)
    case channel
    when 'email' then lead.email.downcase
    when 'sms' then normalized_phone
    else inbox.channel_type == 'Channel::TwilioSms' ? "whatsapp:#{whatsapp_phone}" : whatsapp_phone.delete('+')
    end
  end

  # Sent as the system (no sender) so it does not show up as an agent reply
  def send_message(conversation)
    conversation.messages.create!(
      account_id: account.id, inbox_id: conversation.inbox_id, message_type: :outgoing,
      content: Facebook::LeadAds::Message.template,
      additional_attributes: @template_params ? { 'template_params' => @template_params } : {}
    )
  end

  def contact
    @contact ||= find_contact || create_contact
  end

  def contact_phone
    normalized_phone || whatsapp_phone
  end

  def find_contact
    (lead.email.present? && account.contacts.from_email(lead.email)) ||
      (contact_phone && account.contacts.find_by(phone_number: contact_phone))
  end

  def create_contact
    account.contacts.create!(name: lead.name.presence || lead.email || contact_phone, email: lead.email.presence, phone_number: contact_phone,
                             contact_type: :lead)
  end

  def result(channel, status, inbox: nil, conversation: nil, **details)
    { 'channel' => channel, 'status' => status, 'inbox_id' => inbox&.id, 'inbox_name' => inbox&.name,
      'conversation_id' => conversation&.display_id, 'error' => details[:error], 'address' => details[:address] }
  end

  def overall_status(results)
    statuses = results.pluck('status')
    others = statuses - %w[sent skipped]
    return others.include?('failed') ? 'failed' : 'needs_config' if others.any? && statuses.exclude?('sent')
    return 'partial' if others.any?

    statuses.include?('sent') ? 'sent' : 'skipped'
  end
end
