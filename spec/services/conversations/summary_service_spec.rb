require 'rails_helper'

RSpec.describe Conversations::SummaryService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation: conversation) }

  describe '#perform' do
    context 'when conversation has messages' do
      let!(:message1) { create(:message, conversation: conversation, content: 'Hello') }
      let!(:message2) { create(:message, conversation: conversation, content: 'How can I help?') }

      it 'returns a result' do
        result = service.perform
        expect(result).to be_present
      end
    end

    context 'when conversation has no messages' do
      it 'returns a service response' do
        result = service.perform
        expect(result).to be_present
        expect(result).to have_key(:success)
      end
    end
  end
end
