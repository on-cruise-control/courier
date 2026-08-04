require 'rails_helper'

RSpec.describe Conversations::ActivityMessageJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message_params) do
    { content: 'Activity message', account_id: account.id, inbox_id: inbox.id, message_type: :activity }
  end

  describe '#perform' do
    it 'creates an activity message on the conversation' do
      expect do
        described_class.perform_now(conversation, message_params)
      end.to change(conversation.messages, :count).by(1)

      last_message = conversation.messages.last
      expect(last_message.content).to eq('Activity message')
      expect(last_message.message_type).to eq('activity')
    end
  end
end
