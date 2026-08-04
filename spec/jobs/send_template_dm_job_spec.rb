require 'rails_helper'

RSpec.describe SendTemplateDmJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox) }

  describe '#perform' do
    context 'when contact_inbox is not found' do
      it 'returns without action' do
        described_class.perform_now(nil, conversation, 1)
      end
    end

    context 'when conversation is nil' do
      it 'returns without action' do
        described_class.perform_now(contact_inbox.id, nil, 1)
      end
    end

    context 'when type is unsupported' do
      it 'returns without action' do
        allow(contact).to receive(:get_source_id).and_return('source_123')
        allow(Rails.cache).to receive(:exist?).and_return(false)
        allow(Rails.cache).to receive(:write)

        described_class.perform_now(contact_inbox.id, conversation, 1)
      end
    end
  end
end
