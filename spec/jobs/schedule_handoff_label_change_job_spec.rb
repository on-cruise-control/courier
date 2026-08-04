require 'rails_helper'

RSpec.describe ScheduleHandoffLabelChangeJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, last_handoff_at: Time.current) }

  describe '#perform' do
    context 'when conversation is nil' do
      it 'returns without action' do
        expect { described_class.perform_now(nil) }.not_to raise_error
      end
    end

    context 'when conversation is present' do
      it 'clears the last_handoff_at column' do
        described_class.perform_now(conversation)
        expect(conversation.reload.last_handoff_at).to be_nil
      end
    end
  end
end
