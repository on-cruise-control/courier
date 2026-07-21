require 'rails_helper'

RSpec.describe Instagram::BaseSendService do
  let(:account) { create(:account) }
  let(:instagram_channel) { create(:channel_instagram_fb_page, account: account, instagram_id: 'test-ig-id') }

  before do
    # Stub method used in Inbox.ensure_instagram_profile_url for any channel instance
    subject { TestSendService.new(message: message) }

    before do
      allow_any_instance_of(Channel::FacebookPage).to receive(:instagram_profile_url).and_return('https://instagram.com/profile')
    end

    let(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account) }
    let(:contact) { create(:contact, account: account) }
    let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: instagram_inbox) }
    let(:conversation) { create(:conversation, contact: contact, inbox: instagram_inbox, contact_inbox: contact_inbox) }
    let(:message) { create(:message, conversation: conversation, inbox: instagram_inbox, account: account, content: 'hello') }

    # Concrete subclass implementing abstract methods for testing
    class TestSendService < Instagram::BaseSendService
      def send_message(_payload)
        # No actual API call
      end

      def merge_human_agent_tag(params)
        params # simply return unchanged params
      end
    end

    describe '#perform_reply' do
      context 'when message has content only' do
        it 'calls send_content' do
          expect(subject).to receive(:send_content).once.and_call_original
          expect(subject).not_to receive(:send_attachments)
          subject.perform_reply
        end
      end

      context 'when message has attachments' do
        before do
          attachment = message.attachments.create!(account: account, file_type: :image)
          attachment.file.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
        end

        it 'calls send_attachments' do
          expect(subject).to receive(:send_attachments).once.and_call_original
          expect(subject).to receive(:send_content).once.and_call_original
          subject.perform_reply
        end
      end
    end

    describe '#handle_error' do
      let(:error) { StandardError.new('boom') }

      it 'tracks exception via ChatwootExceptionTracker' do
        expect(ChatwootExceptionTracker).to receive(:new).with(error, account: message.account, user: message.sender).and_call_original
        expect_any_instance_of(ChatwootExceptionTracker).to receive(:capture_exception)
        subject.send(:handle_error, error)
      end
    end
  end
end
