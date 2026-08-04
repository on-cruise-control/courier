require 'rails_helper'

RSpec.describe Conversations::BookingFollowUpJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '#perform' do
    context 'when conversation is not found' do
      it 'returns without action' do
        expect do
          described_class.perform_now(nil)
        end.not_to change(Message, :count)
      end
    end

    context 'when conversation is spam' do
      it 'returns without creating a message' do
        conversation.update!(is_spam: true)
        expect do
          described_class.perform_now(conversation.id)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when conversation is blacklisted' do
      it 'returns without creating a message' do
        conversation.update!(is_blacklisted: true)
        expect do
          described_class.perform_now(conversation.id)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when conversation is valid' do
      it 'clears the booking_follow_up_jid' do
        conversation.update!(booking_follow_up_jid: 'some_jid')
        described_class.perform_now(conversation.id)
        expect(conversation.reload.booking_follow_up_jid).to be_nil
      end

      it 'creates a follow-up message on the conversation' do
        expect do
          described_class.perform_now(conversation.id)
        end.to change(conversation.messages, :count).by(1)

        last_message = conversation.messages.last
        expect(last_message.content).to include('checking in')
        expect(last_message.message_type).to eq('outgoing')
        expect(last_message.content_attributes['booking_follow_up']).to be true
      end
    end
  end
end
