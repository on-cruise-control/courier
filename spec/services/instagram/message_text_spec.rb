require 'rails_helper'

RSpec.describe Instagram::MessageText do
  subject { described_class.new(messaging, instagram_channel) }

  let(:account) { create(:account) }
  let(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'test-ig-id') }
  let(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: instagram_inbox) }
  let(:conversation) { create(:conversation, contact: contact, inbox: instagram_inbox, contact_inbox: contact_inbox) }
  let(:message) { create(:message, conversation: conversation, inbox: instagram_inbox, account: account) }
  let(:messaging) { { sender: { id: '123' }, recipient: { id: '456' }, message: {} } }

  before do
    # Stub method used in Inbox.ensure_instagram_profile_url for any channel instance
    allow_any_instance_of(Channel::Instagram).to receive(:instagram_profile_url).and_return('https://instagram.com/profile')
    # Prevent external HTTP calls during channel callbacks
    allow_any_instance_of(Channel::Instagram).to receive(:subscribe).and_return(true)
    allow_any_instance_of(Channel::Instagram).to receive(:unsubscribe).and_return(true)
    # Stub contact creation to avoid external dependencies
    allow_any_instance_of(Channel::Instagram).to receive(:create_contact_inbox) do |_channel, instagram_id, name|
      contact = Contact.create!(account: account, name: name)
      ContactInbox.create!(contact: contact, inbox: instagram_inbox, source_id: instagram_id)
    end
    # Ensure the service finds the correct inbox using the channel
    instagram_inbox
    subject.send(:inbox_channel, instagram_channel.instagram_id)
  end

  describe '#ensure_contact' do
    it 'does not raise when fetch_instagram_user returns nil' do
      allow(subject).to receive(:fetch_instagram_user).and_return(nil)
      expect { subject.send(:ensure_contact, 'any_id') }.not_to raise_error
    end

    it 'creates a contact when user data is present' do
      user_data = { 'id' => 'user123', 'name' => 'Test User', 'username' => 'testuser', 'profile_pic' => 'http://example.com/pic.png' }
      allow(subject).to receive(:fetch_instagram_user).and_return(user_data)
      expect { subject.send(:ensure_contact, 'user123') }.to change(Contact, :count).by(1)
    end
  end

  describe '#process_successful_response' do
    it 'parses JSON response correctly' do
      response = double(body: { name: 'John', username: 'john', profile_pic: 'url', id: '1', follower_count: 10, is_user_follow_business: false,
                                is_business_follow_user: false, is_verified_user: false }.to_json)
      result = subject.send(:process_successful_response, response)
      expect(result['name']).to eq('John')
      expect(result['username']).to eq('john')
    end
  end

  describe '#handle_error_response' do
    it 'ignores consent error code 230' do
      resp = double(parsed_response: { 'error' => { 'message' => 'Consent needed', 'code' => 230 } })
      expect(subject.send(:handle_error_response, resp, '123')).to be_nil
    end

    it 'sets reauthorization flag for error code 190' do
      resp = double(parsed_response: { 'error' => { 'message' => 'Expired', 'code' => 190 } })
      expect(instagram_channel).to receive(:authorization_error!).once
      subject.send(:handle_error_response, resp, '123')
    end

    it 'creates unknown user for error codes 9010 and 100' do
      resp1 = double(parsed_response: { 'error' => { 'message' => 'App not ready', 'code' => 9010 } })
      unknown1 = subject.send(:handle_error_response, resp1, 'abc')
      expect(unknown1['name']).to include('Unknown')

      resp2 = double(parsed_response: { 'error' => { 'message' => 'Missing', 'code' => 100 } })
      unknown2 = subject.send(:handle_error_response, resp2, 'def')
      expect(unknown2['name']).to include('Unknown')
    end
  end
end
