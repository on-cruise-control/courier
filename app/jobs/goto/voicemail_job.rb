# Runs after a call report ends in voicemail: attaches the voicemail audio to the call message and adds its transcript when ready.
class Goto::VoicemailJob < ApplicationJob
  queue_as :low

  rescue_from(StandardError) { |error| ChatwootExceptionTracker.new(error).capture_exception }

  RETRY_INTERVAL = 30.seconds
  MAX_ATTEMPTS = 8

  def perform(channel_id, call_id, attempt = 1)
    @channel = Channel::GotoSms.find(channel_id)
    @message = Goto::CallEventService.find_message(@channel.inbox, call_id)
    @data = @message.content_attributes['data'].to_h
    voicemail = find_voicemail
    return retry_later(channel_id, call_id, attempt) if voicemail.blank?

    pending = save_voicemail(voicemail)
    retry_later(channel_id, call_id, attempt) if pending
  end

  private

  def save_voicemail(voicemail)
    @message.with_lock { attach_audio(voicemail) unless @message.attachments.exists? }
    @data = @message.reload.content_attributes['data'].to_h
    pending = add_transcript(voicemail['voicemailId'])
    @data['voicemail_id'] = voicemail['voicemailId']
    @data['media_ready'] = @message.attachments.exists?
    @message.update!(content: @data['transcript'].presence || @message.content,
                     content_attributes: @message.content_attributes.merge('data' => @data))
    pending
  end

  # Returns true while the transcript is still being produced.
  def add_transcript(voicemail_id)
    transcription = get_json("/voicemail/v1/voicemails/#{voicemail_id}/transcription")
    @data['transcript'] = transcription['text'] if transcription&.dig('status') == 'SUCCESS'
    transcription&.dig('status').in?(%w[IN_PROGRESS NOT_INITIATED])
  end

  def retry_later(channel_id, call_id, attempt)
    self.class.set(wait: RETRY_INTERVAL).perform_later(channel_id, call_id, attempt + 1) if attempt < MAX_ATTEMPTS
  end

  def find_voicemail
    return if @data['voicemailbox_id'].blank?

    get_json("/voicemail/v1/voicemailboxes/#{@data['voicemailbox_id']}/voicemails?sort=-timestamp&pageSize=10")
      &.dig('items')&.find { |item| item['legId'] == @data['caller_leg_id'] }
  end

  def attach_audio(voicemail)
    response = request("/voicemail/v1/voicemails/#{voicemail['voicemailId']}/mediacontent", 'Accept' => 'audio/mpeg')
    return unless response.success?

    @message.attachments.create!(account_id: @message.account_id, file_type: :audio,
                                 file: { io: StringIO.new(response.body), filename: 'voicemail.mp3', content_type: 'audio/mpeg' })
  end

  def get_json(path)
    response = request(path)
    JSON.parse(response.body) if response.success?
  end

  def request(path, headers = {})
    Faraday.get("#{Channel::GotoSms::API_URL}#{path}", nil, { 'Authorization' => "Bearer #{@channel.access_token!}" }.merge(headers))
  end
end
