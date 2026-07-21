require 'rails_helper'

RSpec.describe Conversations::FollowUpJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '#perform' do
    context 'when conversation is not found' do
      it 'returns without action' do
        expect do
          described_class.perform_now(nil, 1)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when conversation is spam' do
      it 'returns without action' do
        conversation.update!(is_spam: true)
        expect do
          described_class.perform_now(conversation.id, 1)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when conversation is blacklisted' do
      it 'returns without action' do
        conversation.update!(is_blacklisted: true)
        expect do
          described_class.perform_now(conversation.id, 1)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when conversation has stop_follow_up set' do
      it 'returns without action' do
        conversation.update!(stop_follow_up: true)
        expect do
          described_class.perform_now(conversation.id, 1)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when conversation has an assignee' do
      it 'returns without action' do
        conversation.update!(assignee_id: 1)
        expect do
          described_class.perform_now(conversation.id, 1)
        end.not_to change(conversation.messages, :count)
      end
    end

    context 'when last message is incoming' do
      it 'returns without action' do
        create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming)
        expect do
          described_class.perform_now(conversation.id, 1)
        end.not_to change(conversation.messages, :count)
      end
    end
  end
end
