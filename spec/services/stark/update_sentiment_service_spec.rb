require 'rails_helper'

RSpec.describe Stark::UpdateSentimentService do
  let(:service) { described_class.new }
  let(:stark_endpoint) { 'https://api.stark.example.com/analyze' }

  before do
    allow(GlobalConfig).to receive(:get_value).with('STARK_COMMENT_ANALYSIS_ENDPOINT').and_return(stark_endpoint)
    allow(ENV).to receive(:fetch).with('STARK_API_KEY').and_return('fake_api_key')
  end

  describe '#update' do
    context 'when comment id is blank' do
      it 'returns error' do
        result = service.update('')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Missing comment ID')
      end
    end

    context 'when API request is successful' do
      let(:response_body) { { 'metadata' => { 'status_code' => 200 } }.to_json }
      let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

      before do
        allow(HTTParty).to receive(:put).and_return(mock_response)
      end

      it 'returns success' do
        result = service.update('stark_comment_1', reason: 'manual override')
        expect(result[:status]).to eq('success')
      end
    end

    context 'when API request fails' do
      let(:response_body) do
        {
          'metadata' => { 'status_code' => 400 },
          'body' => { 'message' => 'Invalid status' }
        }.to_json
      end
      let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

      before do
        allow(HTTParty).to receive(:put).and_return(mock_response)
      end

      it 'returns error status' do
        result = service.update('stark_comment_1', reason: 'manual override')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Invalid status')
      end
    end
  end
end
