require 'rails_helper'

RSpec.describe MacrosExecutionJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:macro) { create(:macro, account: account) }
  let(:conversation) { create(:conversation, account: account, display_id: 1001) }
  let(:execution_service) { instance_double(Macros::ExecutionService) }

  describe '#perform' do
    it 'calls Macros::ExecutionService for each conversation' do
      allow(Macros::ExecutionService).to receive(:new).with(macro, conversation, user).and_return(execution_service)
      allow(execution_service).to receive(:perform)

      described_class.perform_now(macro, conversation_ids: [conversation.display_id], user: user)

      expect(Macros::ExecutionService).to have_received(:new).with(macro, conversation, user)
      expect(execution_service).to have_received(:perform)
    end

    context 'when no conversations match the display_ids' do
      it 'does not call Macros::ExecutionService' do
        expect(Macros::ExecutionService).not_to receive(:new)

        described_class.perform_now(macro, conversation_ids: [999_999], user: user)
      end
    end
  end
end
