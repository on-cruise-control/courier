require 'rails_helper'

RSpec.describe ActionCableBroadcastJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:members) { %w[user_1 user_2] }
  let(:event_name) { 'conversation.created' }
  let(:data) { { account_id: account.id, id: conversation.display_id } }

  describe '#perform' do
    context 'when members is blank' do
      it 'returns without broadcasting' do
        expect(ActionCable.server).not_to receive(:broadcast)
        described_class.perform_now([], event_name, data)
      end
    end

    context 'when members are present' do
      it 'broadcasts to each member' do
        expect(ActionCable.server).to receive(:broadcast).twice
        described_class.perform_now(members, event_name, data)
      end
    end

    context 'with conversation update events' do
      let(:event_name) { 'conversation.status_changed' }

      it 'fetches latest conversation data' do
        expect(ActionCable.server).to receive(:broadcast).with(
          'user_1',
          hash_including(event: event_name)
        )
        described_class.perform_now(['user_1'], event_name, data)
      end
    end
  end
end
