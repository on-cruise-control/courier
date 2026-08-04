require 'rails_helper'

RSpec.describe Conversations::TypingStatusManager do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:user) { create(:user, account: account) }
  let(:params) { { typing_status: 'on', is_private: false } }
  let(:service) { described_class.new(conversation, user, params) }

  describe '#toggle_typing_status' do
    context 'when typing_status is on' do
      it 'triggers typing on event' do
        expect(service).to receive(:trigger_typing_event).with(
          Conversations::TypingStatusManager::CONVERSATION_TYPING_ON,
          false
        )
        service.toggle_typing_status
      end
    end

    context 'when typing_status is off' do
      let(:params) { { typing_status: 'off', is_private: false } }

      it 'triggers typing off event' do
        expect(service).to receive(:trigger_typing_event).with(
          Conversations::TypingStatusManager::CONVERSATION_TYPING_OFF,
          false
        )
        service.toggle_typing_status
      end
    end
  end
end
