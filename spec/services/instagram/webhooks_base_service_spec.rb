require 'rails_helper'

RSpec.describe Instagram::WebhooksBaseService do
  subject { TestWebhooksService.new(instagram_channel) }

  let(:account) { create(:account) }
  let(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'test-ig-id') }
  let(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:user_data) do
    {
      'id' => 'ig_user_123',
      'name' => 'Test User',
      'username' => 'testuser',
      'profile_pic' => 'http://example.com/pic.png',
      'follower_count' => 100,
      'is_user_follow_business' => true,
      'is_business_follow_user' => false,
      'is_verified_user' => true
    }
  end

  before do
    allow_any_instance_of(Channel::Instagram).to receive(:subscribe).and_return(true)
    allow_any_instance_of(Channel::Instagram).to receive(:unsubscribe).and_return(true)
  end

  # Create a concrete subclass to expose protected methods for testing
  class TestWebhooksService < Instagram::WebhooksBaseService
    public :inbox_channel, :find_or_create_contact, :build_instagram_attributes
  end

  describe '#inbox_channel' do
    it 'loads the correct inbox for the channel' do
      instagram_inbox # ensure the inbox is created
      subject.inbox_channel('any_id')
      expect(subject.instance_variable_get(:@inbox)).to eq(instagram_inbox)
    end
  end

  describe '#find_or_create_contact' do
    before do
      instagram_inbox # ensure the inbox is created
      subject.inbox_channel('any_id')
    end

    context 'when contact already exists' do
      before do
        # Pre‑create contact_inbox
        instagram_inbox.channel.create_contact_inbox(user_data['id'], user_data['name'])
      end

      it 'does not create a new contact' do
        expect { subject.find_or_create_contact(user_data) }.not_to change(Contact, :count)
        expect(subject.instance_variable_get(:@contact)).to be_present
      end
    end

    context 'when contact does not exist' do
      it 'creates a new contact and enqueues avatar job when profile_pic present' do
        allow(Avatar::AvatarFromUrlJob).to receive(:perform_later)
        expect { subject.find_or_create_contact(user_data) }.to change(Contact, :count).by(1)
        expect(Avatar::AvatarFromUrlJob).to have_received(:perform_later).once
        expect(subject.instance_variable_get(:@contact).additional_attributes['social_profiles']['instagram']).to eq(user_data['username'])
      end
    end
  end

  describe '#build_instagram_attributes' do
    it 'includes optional fields when present' do
      attrs = subject.build_instagram_attributes(user_data)
      expect(attrs['social_instagram_follower_count']).to eq(100)
      expect(attrs['social_instagram_is_user_follow_business']).to eq(true)
      expect(attrs['social_instagram_is_business_follow_user']).to eq(false)
      expect(attrs['social_instagram_is_verified_user']).to eq(true)
    end

    it 'does not include optional fields when missing' do
      minimal = user_data.slice('id', 'username')
      attrs = subject.build_instagram_attributes(minimal)
      expect(attrs).not_to have_key('social_instagram_follower_count')
    end
  end
end
