require 'rails_helper'

describe Messages::Instagram::BaseMessageBuilder do
  subject(:base_message_builder) { described_class }

  before do
    stub_request(:post, /graph\.instagram\.com/)
    stub_request(:get, 'https://www.example.com/test.jpeg')
      .to_return(status: 200, body: '', headers: {})
  end

  let!(:account) { create(:account) }
  let!(:instagram_channel) { create(:channel_instagram, account: account, instagram_id: 'chatwoot-app-user-id-1') }
  let!(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account, greeting_enabled: false) }
  let!(:dm_params) { build(:instagram_message_create_event).with_indifferent_access }

  describe '#perform' do
    before do
      instagram_channel.update(access_token: 'valid_instagram_token')

      stub_request(:get, %r{https://graph\.instagram\.com/.*?/Sender-id-.*?\?.*})
        .to_return(
          status: 200,
          body: proc { |request|
            sender_id = request.uri.path.split('/').last.split('?').first
            {
              name: 'Jane',
              username: 'some_user_name',
              profile_pic: 'https://chatwoot-assets.local/sample.png',
              id: sender_id,
              follower_count: 100,
              is_user_follow_business: true,
              is_business_follow_user: true,
              is_verified_user: false
            }.to_json
          },
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns early if reauthorization is required' do
      # Mock the reauthorization_required? method
      allow_any_instance_of(Channel::Instagram).to receive(:reauthorization_required?).and_return(true)

      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)

      expect do
        described_class.new(messaging, instagram_inbox).perform
      end.not_to change(Message, :count)
    end

    it 'creates contact and message for the instagram direct inbox' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      described_class.new(messaging, instagram_inbox).perform

      instagram_inbox.reload

      expect(instagram_inbox.conversations.count).to be 1
      expect(instagram_inbox.messages.count).to be 1

      message = instagram_inbox.messages.first
      expect(message.content).to eq('This is the first message from the customer')
    end

    it 'handles errors gracefully' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)

      # Simulate an error by making the contact_inbox lookup fail
      allow_any_instance_of(described_class).to receive(:contact).and_raise(StandardError, 'Test error')

      expect do
        described_class.new(messaging, instagram_inbox).perform
      end.not_to raise_error
    end
  end

  describe '#message_type' do
    it 'returns :incoming for normal messages' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_type)).to eq(:incoming)
    end

    it 'returns :outgoing for echo messages' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox, outgoing_echo: true)

      expect(builder.send(:message_type)).to eq(:outgoing)
    end
  end

  describe '#message_identifier' do
    it 'returns the message mid' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_identifier)).to eq(messaging[:message][:mid])
    end
  end

  describe '#message_source_id' do
    it 'returns sender_id for incoming messages' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_source_id)).to eq(messaging[:sender][:id])
    end

    it 'returns recipient_id for outgoing echo messages' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox, outgoing_echo: true)

      expect(builder.send(:message_source_id)).to eq(messaging[:recipient][:id])
    end
  end

  describe '#message_is_unsupported?' do
    it 'returns true when message is unsupported' do
      messaging = dm_params[:entry][0]['messaging'][0]
      messaging[:message][:is_unsupported] = true
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_is_unsupported?)).to be true
    end

    it 'returns false when message is not unsupported' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_is_unsupported?)).to be false
    end
  end

  describe '#attachments' do
    it 'returns empty hash when no attachments' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:attachments)).to eq({})
    end

    it 'returns attachments when present' do
      messaging = dm_params[:entry][0]['messaging'][0]
      messaging[:message][:attachments] = [{ type: 'image', payload: { url: 'https://example.com/image.jpg' } }]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:attachments)).to eq(messaging[:message][:attachments])
    end
  end

  describe '#message_content' do
    it 'returns the message text' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_content)).to eq(messaging[:message][:text])
    end
  end

  describe '#story_reply_attributes' do
    it 'returns story attributes when present' do
      messaging = dm_params[:entry][0]['messaging'][0]
      story_data = { 'url' => 'https://example.com/story', 'id' => 'story-id-123' }
      messaging[:message][:reply_to] = { 'story' => story_data }
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:story_reply_attributes)).to eq(story_data)
    end

    it 'returns nil when story reply is not present' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:story_reply_attributes)).to be_nil
    end
  end

  describe '#message_reply_attributes' do
    it 'returns message mid when reply is present' do
      messaging = dm_params[:entry][0]['messaging'][0]
      reply_mid = 'message-id-reply-123'
      messaging[:message][:reply_to] = { 'mid' => reply_mid }
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_reply_attributes)).to eq(reply_mid)
    end

    it 'returns nil when reply is not present' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_reply_attributes)).to be_nil
    end
  end

  describe '#contact' do
    it 'returns the contact for the message source' do
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:contact)).to eq(contact)
    end
  end

  describe '#conversation' do
    it 'returns existing conversation when lock_to_single_conversation is true' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)

      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:conversation)).to eq(conversation)
    end

    it 'returns existing open conversation when lock_to_single_conversation is false' do
      instagram_inbox.update!(lock_to_single_conversation: false)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id, status: :open)

      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:conversation)).to eq(conversation)
    end
  end

  describe '#message_params' do
    it 'returns correct params for incoming message' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      params = builder.send(:message_params)

      expect(params[:message_type]).to eq(:incoming)
      expect(params[:status]).to eq(:sent)
      expect(params[:source_id]).to eq(messaging[:message][:mid])
      expect(params[:content]).to eq(messaging[:message][:text])
      expect(params[:content_attributes][:in_reply_to_external_id]).to be_nil
    end

    it 'returns correct params for outgoing echo message' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id, contact_id: contact.id)
      builder = described_class.new(messaging, instagram_inbox, outgoing_echo: true)
      allow(builder).to receive(:conversation).and_return(conversation)

      params = builder.send(:message_params)

      expect(params[:message_type]).to eq(:outgoing)
      expect(params[:status]).to eq(:delivered)
      expect(params[:sender]).to be_nil
      expect(params[:content_attributes][:external_echo]).to be true
    end

    it 'includes unsupported flag for unsupported messages' do
      messaging = dm_params[:entry][0]['messaging'][0]
      messaging[:message][:is_unsupported] = true
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      params = builder.send(:message_params)

      expect(params[:content_attributes][:is_unsupported]).to be true
    end
  end

  describe '#message_already_exists?' do
    it 'returns true when message with same source_id exists' do
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      create(:message, account_id: account.id, inbox_id: instagram_inbox.id, conversation_id: conversation.id,
                       message_type: 'incoming', source_id: messaging[:message][:mid])

      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_already_exists?)).to be true
    end

    it 'returns false when message does not exist' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:message_already_exists?)).to be false
    end
  end

  describe '#recent_duplicate_echo?' do
    it 'returns true when recent duplicate text echo exists' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      create(:message, account_id: account.id, inbox_id: instagram_inbox.id, conversation_id: conversation.id,
                       message_type: 'outgoing', content: messaging[:message][:text])

      builder = described_class.new(messaging, instagram_inbox, outgoing_echo: true)
      # Mock the conversation method to return our created conversation
      allow(builder).to receive(:conversation).and_return(conversation)

      expect(builder.send(:recent_duplicate_echo?)).to be true
    end

    it 'returns false when no recent duplicate echo exists' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      builder = described_class.new(messaging, instagram_inbox, outgoing_echo: true)
      # Mock the conversation method to return our created conversation
      allow(builder).to receive(:conversation).and_return(conversation)

      expect(builder.send(:recent_duplicate_echo?)).to be false
    end
  end

  describe '#all_unsupported_files?' do
    it 'returns true when all attachments are unsupported' do
      messaging = dm_params[:entry][0]['messaging'][0]
      messaging[:message][:attachments] = [{ 'type' => 'unsupported_type' }]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:all_unsupported_files?)).to be true
    end

    it 'returns false when no attachments' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:all_unsupported_files?)).to be_nil
    end

    it 'returns false when attachments have supported types' do
      messaging = dm_params[:entry][0]['messaging'][0]
      messaging[:message][:attachments] = [{ 'type' => 'image' }]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:all_unsupported_files?)).to be false
    end
  end

  describe '#build_conversation' do
    it 'creates a new conversation with correct attributes' do
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)

      builder = described_class.new(messaging, instagram_inbox)
      conversation = builder.send(:build_conversation)

      expect(conversation).to be_persisted
      expect(conversation.account_id).to eq(instagram_inbox.account_id)
      expect(conversation.inbox_id).to eq(instagram_inbox.id)
      expect(conversation.contact_id).to eq(contact.id)
    end
  end

  describe '#conversation_params' do
    it 'returns correct conversation parameters' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      params = builder.send(:conversation_params)

      expect(params[:account_id]).to eq(instagram_inbox.account_id)
      expect(params[:inbox_id]).to eq(instagram_inbox.id)
      expect(params[:contact_id]).to eq(builder.send(:contact).id)
    end
  end

  describe '#additional_conversation_attributes' do
    it 'returns empty hash by default' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect(builder.send(:additional_conversation_attributes)).to eq({})
    end
  end

  describe '#ensure_story_mention_content' do
    it 'updates content for outgoing story mention messages' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      described_class.new(messaging, instagram_inbox).perform

      message = instagram_inbox.messages.first
      message.update!(message_type: 'outgoing', content_attributes: { image_type: 'story_mention' })

      builder = described_class.new(messaging, instagram_inbox)
      allow(builder).to receive(:conversation).and_return(conversation)
      allow(builder).to receive(:contact).and_return(contact)
      allow(builder).to receive(:story_reply_username).and_return(contact.name)
      # Set the instance variable directly since the method uses @message
      builder.instance_variable_set(:@message, message)
      builder.send(:ensure_story_mention_content)

      message.reload
      expect(message.content).to include(contact.name)
    end

    it 'updates content for incoming story mention messages with blank content' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      described_class.new(messaging, instagram_inbox).perform

      message = instagram_inbox.messages.first
      message.update!(content: nil, content_attributes: { image_type: 'story_mention' })

      builder = described_class.new(messaging, instagram_inbox)
      allow(builder).to receive(:conversation).and_return(conversation)
      allow(builder).to receive(:contact).and_return(contact)
      allow(builder).to receive(:story_sender_label).and_return(contact.name)
      # Set the instance variable directly since the method uses @message
      builder.instance_variable_set(:@message, message)
      builder.send(:ensure_story_mention_content)

      message.reload
      expect(message.content).to be_present
    end
  end

  describe '#story_reply_username' do
    it 'returns contact name when available' do
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      username = builder.send(:story_reply_username)
      expect(username).to eq(contact.name)
    end
  end

  describe '#story_sender_label' do
    it 'returns contact name when story sender is blank' do
      instagram_inbox.update!(lock_to_single_conversation: true)
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      described_class.new(messaging, instagram_inbox).perform

      message = instagram_inbox.messages.first
      builder = described_class.new(messaging, instagram_inbox)
      allow(builder).to receive(:conversation).and_return(conversation)
      allow(builder).to receive(:contact).and_return(contact)
      # Set the instance variable directly since the method uses @message
      builder.instance_variable_set(:@message, message)

      label = builder.send(:story_sender_label)
      expect(label).to eq(contact.name)
    end
  end

  describe '#find_message_by_source_id' do
    it 'returns message when source_id exists' do
      messaging = dm_params[:entry][0]['messaging'][0]
      sender_id = messaging['sender']['id']
      contact = create_instagram_contact_for_sender(sender_id, instagram_inbox)
      conversation = create(:conversation, account_id: account.id, inbox_id: instagram_inbox.id,
                                           contact_id: contact.id)
      message = create(:message, account_id: account.id, inbox_id: instagram_inbox.id,
                                 conversation_id: conversation.id, source_id: messaging[:message][:mid])

      builder = described_class.new(messaging, instagram_inbox)
      found_message = builder.send(:find_message_by_source_id, messaging[:message][:mid])

      expect(found_message).to eq(message)
    end

    it 'returns nil when source_id does not exist' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      found_message = builder.send(:find_message_by_source_id, 'non-existent-id')

      expect(found_message).to be_nil
    end
  end

  describe '#handle_error' do
    it 'captures exception and returns true' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      error = StandardError.new('Test error')
      expect(ChatwootExceptionTracker).to receive(:new).with(error, account: instagram_inbox.account).and_return(
        double(capture_exception: true)
      )

      result = builder.send(:handle_error, error)

      expect(result).to be true
    end
  end

  describe 'abstract methods' do
    it 'raises NotImplementedError for get_story_object_from_source_id' do
      messaging = dm_params[:entry][0]['messaging'][0]
      create_instagram_contact_for_sender(messaging['sender']['id'], instagram_inbox)
      builder = described_class.new(messaging, instagram_inbox)

      expect { builder.send(:get_story_object_from_source_id, 'test-id') }.to raise_error(NotImplementedError)
    end
  end
end
