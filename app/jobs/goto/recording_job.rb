# Runs after a call report that has a recording: attaches the call audio to the call message and adds its transcript when ready.
class Goto::RecordingJob < ApplicationJob
  queue_as :low

  rescue_from(StandardError) { |error| ChatwootExceptionTracker.new(error).capture_exception }

  RETRY_INTERVAL = 30.seconds
  MAX_ATTEMPTS = 8

  def perform(channel_id, call_id, attempt = 1)
    @channel = Channel::GotoSms.find(channel_id)
    @message = Goto::CallEventService.find_message(@channel.inbox, call_id)
    @recording_id = @message.content_attributes.dig('data', 'recording_id')
    return retry_later(channel_id, call_id, attempt) unless get_json("/recording/v1/recordings/#{@recording_id}")&.dig('status') == 'UPLOADED'

    save_audio_and_transcript(fetch_transcript)
    retry_later(channel_id, call_id, attempt) if @message.reload.content_attributes.dig('data', 'transcript').blank?
  end

  private

  # The audio is stored first and the message is updated afterwards.
  def save_audio_and_transcript(transcript)
    attach_audio_once
    data = @message.reload.content_attributes['data']
    transcript = data['transcript'].presence || transcript
    data = data.merge('transcript' => transcript, 'media_ready' => @message.attachments.exists?).compact
    @message.update!(content: transcript.presence || @message.content, content_attributes: @message.content_attributes.merge('data' => data))
  end

  def attach_audio_once
    @message.with_lock do
      next if @message.attachments.exists? || @message.content_attributes.dig('data', 'outcome') == 'VOICEMAIL'

      attach_audio
    end
  end

  def retry_later(channel_id, call_id, attempt)
    self.class.set(wait: RETRY_INTERVAL).perform_later(channel_id, call_id, attempt + 1) if attempt < MAX_ATTEMPTS
  end

  # GoTo answers both the content and the transcription requests with a redirect to a signed file URL.
  def attach_audio
    token = get_json("/recording/v1/recordings/#{@recording_id}/content")&.dig('token', 'token')
    url = redirect_url("/recording/v1/recordings/#{@recording_id}/content/#{token}")
    return if token.blank? || url.blank?

    @message.attachments.create!(account_id: @message.account_id, file_type: :audio,
                                 file: { io: StringIO.new(Faraday.get(url).body), filename: 'recording.mp3', content_type: 'audio/mpeg' })
  end

  def fetch_transcript
    url = redirect_url("/recording/v1/transcriptions/#{@recording_id}")
    return if url.blank?

    JSON.parse(Faraday.get(url).body)['results'].filter_map { |result| result['transcript']&.strip.presence }.join(' ')
  end

  def redirect_url(path)
    request(path).headers['location']
  end

  def get_json(path)
    response = request(path)
    JSON.parse(response.body) if response.success?
  end

  def request(path)
    Faraday.get("#{Channel::GotoSms::API_URL}#{path}", nil, 'Authorization' => "Bearer #{@channel.access_token!}")
  end
end
