require 'rails_helper'

RSpec.describe Dealership::BookingPeriodicCheckJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  describe '#perform' do
    context 'when conversation is not found' do
      it 'returns without action' do
        expect(Dealership::BookingCreateService).not_to receive(:new)
        described_class.perform_now(nil)
      end
    end

    context 'when booking_api_job_id does not match provider_job_id' do
      it 'returns without action' do
        conversation.update!(additional_attributes: { 'booking_api_job_id' => 'different_id' })
        expect(Dealership::BookingCreateService).not_to receive(:new)
        described_class.perform_now(conversation.id)
      end
    end

    context 'when booking_api_job_id matches (both nil for sync execution)' do
      it 'calls the BookingCreateService' do
        conversation.update!(additional_attributes: { 'booking_api_job_id' => nil })

        service = instance_double(Dealership::BookingCreateService)
        expect(Dealership::BookingCreateService).to receive(:new).with(conversation).and_return(service)
        expect(service).to receive(:perform)

        described_class.perform_now(conversation.id)
      end
    end
  end
end
