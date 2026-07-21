require 'rails_helper'

RSpec.describe Stark::CommentAnalysisService do
  let(:service) { described_class.new }
  let(:stark_endpoint) { 'https://api.stark.example.com/analyze' }

  before do
    allow(GlobalConfig).to receive(:get_value).with('STARK_COMMENT_ANALYSIS_ENDPOINT').and_return(stark_endpoint)
    allow(ENV).to receive(:fetch).with('STARK_API_KEY').and_return('fake_api_key')
  end

  describe '#analyze' do
    context 'when comment or dealership_id is blank' do
      it 'returns nil when comment is blank' do
        expect(service.analyze('', 'dealership_123')).to be_nil
      end

      it 'returns nil when dealership_id is blank' do
        expect(service.analyze('Great!', '')).to be_nil
      end
    end

    context 'when API request is successful' do
      let(:response_body) do
        {
          'metadata' => { 'status_code' => 200 },
          'body' => {
            'data' => {
              'sentiment_label' => 'Positive',
              'reply' => 'Thanks!',
              'comment_id' => 'stark_123'
            }
          }
        }.to_json
      end
      let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

      before do
        allow(HTTParty).to receive(:post).and_return(mock_response)
      end

      it 'returns success with parsed data' do
        result = service.analyze('Awesome!', 'dealership_123')

        expect(result[:status]).to eq('success')
        expect(result[:sentiment_label]).to eq('Positive')
        expect(result[:reply]).to eq('Thanks!')
        expect(result[:stark_comment_id]).to eq('stark_123')
      end
    end

    context 'when API returns 400 error' do
      let(:response_body) do
        {
          'metadata' => { 'status_code' => 400 },
          'body' => { 'message' => 'Invalid data' }
        }.to_json
      end
      let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

      before do
        allow(HTTParty).to receive(:post).and_return(mock_response)
      end

      it 'returns error status' do
        result = service.analyze('Awesome!', 'dealership_123')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Invalid data')
      end
    end

    context 'when HTTParty raises an error' do
      before do
        allow(HTTParty).to receive(:post).and_raise(StandardError.new('Connection failed'))
        stub_const('Stark::CommentAnalysisService::RETRY_DELAY', 0)
      end

      it 'retries and returns error status' do
        expect(HTTParty).to receive(:post).twice

        result = service.analyze('Awesome!', 'dealership_123')
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Connection failed')
      end
    end
  end
end
