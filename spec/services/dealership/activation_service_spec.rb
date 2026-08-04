require 'rails_helper'

RSpec.describe Dealership::ActivationService do
  let(:account) { create(:account, dealership_id: 'dealership_123') }
  let(:service) { described_class.new(account) }

  before do
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({ 'DEALERSHIP_API_BASE_URL' => 'https://api.example.com' })
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_KEY').and_return({ 'DEALERSHIP_API_KEY' => 'fake_api_key' })
  end

  describe '#perform' do
    context 'when config is missing' do
      before do
        allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({})
      end

      it 'does not make API call' do
        expect(described_class).not_to receive(:put)
        service.perform(active: true)
      end
    end

    context 'when config is valid' do
      let(:mock_response) { instance_double(HTTParty::Response, success?: true, body: '{}', code: 200) }

      before do
        allow(described_class).to receive(:put).and_return(mock_response)
      end

      it 'makes put request to activate dealership' do
        expect(described_class).to receive(:put).with(
          'https://api.example.com/api/v1/dealerships/dealership_123',
          body: { is_active: true }.to_json,
          headers: {
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer fake_api_key'
          }
        )
        service.perform(active: true)
      end
    end
  end
end
