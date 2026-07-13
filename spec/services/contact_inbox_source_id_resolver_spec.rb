require 'rails_helper'

RSpec.describe ContactInboxSourceIdResolver do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_attributes) { { name: 'John Doe', email: 'john@example.com' } }

  describe '#perform' do
    context 'when contact_inbox already exists' do
      let!(:existing_contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'source123') }

      it 'returns existing contact_inbox' do
        resolver = described_class.new(
          inbox: inbox,
          source_ids: %w[source123 source456],
          contact_attributes: contact_attributes
        )
        result = resolver.perform
        expect(result).to eq(existing_contact_inbox)
      end
    end

    context 'when contact_inbox does not exist' do
      it 'creates new contact_inbox' do
        resolver = described_class.new(
          inbox: inbox,
          source_ids: ['newsource123'],
          contact_attributes: contact_attributes
        )
        result = resolver.perform
        expect(result).to be_present
        expect(result.inbox).to eq(inbox)
        expect(result.source_id).to eq('newsource123')
      end
    end

    context 'with multiple source_ids' do
      it 'finds first matching source_id' do
        create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'source1')
        existing2 = create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'source2')

        resolver = described_class.new(
          inbox: inbox,
          source_ids: %w[source2 source1],
          contact_attributes: contact_attributes
        )
        result = resolver.perform
        expect(result).to eq(existing2)
      end
    end

    context 'with blank source_ids' do
      it 'creates contact_inbox with first non-blank source_id' do
        resolver = described_class.new(
          inbox: inbox,
          source_ids: ['', nil, 'valid_source'],
          contact_attributes: contact_attributes
        )
        result = resolver.perform
        expect(result).to be_present
        expect(result.source_id).to eq('valid_source')
      end
    end
  end
end
