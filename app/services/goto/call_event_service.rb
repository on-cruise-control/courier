class Goto::CallEventService
  pattr_initialize [:channel!, :params!]

  def self.find_message(inbox, call_id)
    inbox.messages.voice_calls.find_by("(content_attributes #>> '{}')::json->'data'->>'call_sid' = ?", call_id)
  end

  def perform
    channel.with_lock do
      @message = self.class.find_message(inbox, call_id)
      @created = @message.blank?
      @message ||= create_message
      next if @message.blank?

      @data = @message.content_attributes['data'].to_h
      report? ? apply_report : apply_state
      save_data
    end
    enqueue_follow_up_jobs
  end

  # Closes a call whose final report never arrived so it doesn't stay ringing or in progress forever.
  def finalize_stale(message)
    @message = message
    @data = message.content_attributes['data'].to_h
    @data['ended_at'] ||= Time.current.iso8601(3)
    @data['reported'] = true
    update_status
    save_data
  end

  private

  def save_data
    @message.update!(content_attributes: @message.content_attributes.merge('data' => @data.compact))
  end

  def enqueue_follow_up_jobs
    Goto::VoicemailJob.perform_later(channel.id, call_id) if @voicemail_left
    Goto::RecordingJob.perform_later(channel.id, call_id) if @recorded
    Goto::CallReconcileJob.set(wait: Goto::CallReconcileJob::INTERVAL).perform_later(channel.id, call_id) if @message && @created
  end

  def inbox
    channel.inbox
  end

  def report?
    params[:type] == 'REPORT_SUMMARY'
  end

  def content
    params[:content]
  end

  def metadata
    report? ? content : content[:metadata]
  end

  def call_id
    metadata[:conversationSpaceId]
  end

  def incoming?
    metadata[:direction] == 'INBOUND'
  end

  def parties
    @parties ||= report? ? [content[:caller], *content[:participants]].compact : Array(content.dig(:state, :participants))
  end

  # The dealership's own number shows up as the PHONE_NUMBER party of the call.
  def line_numbers
    parties.filter_map { |party| party.dig(:type, :number) if party.dig(:type, :value) == 'PHONE_NUMBER' }
  end

  def contact_number
    return report? ? content.dig(:caller, :number) : parties.filter_map { |party| party.dig(:type, :caller, :number) }.first if incoming?

    report? ? Array(content[:participants]).first&.dig(:number) : metadata[:dialString]
  end

  def routed_to_agent?
    return true unless incoming?
    return content[:callAnswered].present? || Array(content[:participants]).any? if report?

    parties.any? { |party| party.dig(:type, :value) == 'LINE' }
  end

  def create_message
    return unless line_numbers.include?(channel.phone_number) && contact_number.present? && routed_to_agent?

    contact, conversation = Goto::ConversationResolver.new(inbox: inbox, phone_number: contact_number).perform
    conversation.messages.create!(
      account_id: inbox.account_id, inbox_id: inbox.id, content: I18n.t('conversations.messages.voice_call.goto'),
      content_type: 'voice_call', message_type: incoming? ? :incoming : :outgoing, sender: incoming? ? contact : nil, status: :delivered,
      content_attributes: {
        external_echo: !incoming?,
        data: { 'call_source' => 'goto', 'call_sid' => call_id, 'call_direction' => incoming? ? 'inbound' : 'outbound', 'status' => 'ringing' }
      }.compact_blank
    )
  end

  def apply_state
    state = content[:state]
    @data['voicemailbox_id'] ||= voicemailbox_id
    if state[:type] == 'ENDING'
      @data['ended_at'] ||= state[:timestamp]
    elsif answered_by_party?
      @data['answered_at'] ||= state[:timestamp]
    end
    update_status
  end

  def recording_id
    [content[:caller], *content[:participants]].compact.filter_map { |party| party[:recordingId] }.first
  end

  def voicemailbox_id
    Array(content[:state][:interactiveVoiceResponseSystems]).filter_map { |ivr| ivr.dig(:type, :voicemailBoxId) }.first
  end

  def answered_by_party?
    answering_type = incoming? ? 'LINE' : 'PHONE_NUMBER'
    parties.any? { |party| party.dig(:status, :value) == 'CONNECTED' && party.dig(:type, :value) == answering_type }
  end

  def apply_report
    answered_at = content[:callAnswered] unless content[:callerOutcome] == 'VOICEMAIL'
    first_report = !@data['reported']
    @voicemail_left = first_report && content[:callerOutcome] == 'VOICEMAIL'
    @data['recording_id'] ||= recording_id
    @recorded = first_report && @data['recording_id'].present?
    @data.merge!('answered_at' => answered_at, 'ended_at' => content[:callEnded], 'caller_leg_id' => content.dig(:caller, :legId),
                 'outcome' => content[:callerOutcome], 'reported' => true)
    update_status
  end

  def call_status(answered_at, ended_at)
    return answered_at ? 'in-progress' : 'ringing' unless ended_at
    return 'completed' if answered_at

    @data['outcome'].to_s.match?(/busy/i) ? 'busy' : 'no-answer'
  end

  def update_status
    answered_at = @data['answered_at']
    ended_at = @data['ended_at']
    @data['status'] = call_status(answered_at, ended_at)
    @data['duration_seconds'] = answered_at && ended_at ? (Time.zone.parse(ended_at) - Time.zone.parse(answered_at)).to_i : nil
  end
end
