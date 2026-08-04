require 'rails_helper'

RSpec.describe Dealership::BookingCreateService do
  let(:account) { create(:account, dealership_id: 'dealership_123') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:service) { described_class.new(conversation, force: true) }

  before do
    allow(inbox).to receive(:platform_name).and_return('Website')
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({ 'DEALERSHIP_API_BASE_URL' => 'https://api.example.com' })
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_KEY').and_return({ 'DEALERSHIP_API_KEY' => 'fake_api_key' })
  end

  describe '#perform' do
    context 'when config is missing' do
      before do
        allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({})
      end

      it 'does not make API call' do
        expect(described_class).not_to receive(:post)
        service.perform
      end
    end

    context 'when config is valid' do
      let(:mock_response) { instance_double(HTTParty::Response, success?: true, body: '{}', code: 200) }

      before do
        allow(described_class).to receive(:post).and_return(mock_response)
      end

      it 'makes post request to create booking' do
        expect(described_class).to receive(:post).with(
          'https://api.example.com/api/v1/bookings',
          body: anything,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer fake_api_key'
          }
        )
        service.perform
      end
    end
  end
end
