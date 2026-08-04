require 'rails_helper'

RSpec.describe Dealership::BookingStatsService do
  let(:service) { described_class.new('dealership_123', period: 'daily') }

  before do
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_BASE_URL').and_return({ 'DEALERSHIP_API_BASE_URL' => 'https://api.example.com' })
    allow(GlobalConfig).to receive(:get).with('DEALERSHIP_API_KEY').and_return({ 'DEALERSHIP_API_KEY' => 'fake_api_key' })
  end

  describe '#fetch_stats' do
    context 'when dealership_id is blank' do
      let(:blank_service) { described_class.new('') }

      it 'returns empty data' do
        expect(blank_service.fetch_stats).to eq({ data: [], period: 'daily' })
      end
    end

    context 'when api request is successful' do
      let(:response_body) { { 'data' => [{ 'id' => 1 }], 'period' => 'daily' } }
      let(:mock_response) { instance_double(HTTParty::Response, code: 200, parsed_response: response_body) }

      before do
        # allow_any_instance_of(Dealership::BookingStatsService).to receive(:make_request).and_return(mock_response)
        allow_any_instance_of(Dealership::BookingStatsService)
          .to receive(:make_request) { mock_response }
      end

      it 'returns parsed stats' do
        result = service.fetch_stats
        expect(result[:data]).to eq([{ 'id' => 1 }])
        expect(result[:period]).to eq('daily')
      end
    end

    context 'when api request fails' do
      let(:mock_response) { instance_double(HTTParty::Response, code: 404, parsed_response: {}) }

      before do
        allow_any_instance_of(Dealership::BookingStatsService).to receive(:make_request).and_return(mock_response)
      end

      it 'returns empty data' do
        result = service.fetch_stats
        expect(result[:data]).to eq([])
      end
    end
  end
end
