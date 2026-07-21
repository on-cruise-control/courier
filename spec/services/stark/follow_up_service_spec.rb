require 'rails_helper'

RSpec.describe Stark::FollowUpService do
  let(:account) { create(:account, dealership_id: '12345678-1234-1234-1234-123456789012') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation, 1) }
  let(:stark_endpoint) { 'https://api.stark.example.com/follow_up' }

  around do |example|
    with_modified_env STARK_API_KEY: 'fake_api_key' do
      example.run
    end
  end

  before do
    allow(GlobalConfig).to receive(:get_value).with('STARK_FOLLOW_UP_ENDPOINT').and_return(stark_endpoint)
  end

  describe '#get_follow_up_content' do
    context 'when dealership_id is invalid' do
      before do
        conversation.account.update!(dealership_id: 'invalid')
      end

      it 'returns nil' do
        expect(service.get_follow_up_content).to be_nil
      end
    end

    context 'when dealership_id is valid' do
      context 'when API request is successful' do
        let(:response_body) do
          {
            'metadata' => { 'status_code' => 200 },
            'body' => {
              'message' => 'Follow up message',
              'metadata' => { 'key' => 'value' }
            }
          }.to_json
        end
        let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

        before do
          allow(HTTParty).to receive(:post).and_return(mock_response)
        end

        it 'returns the message and metadata' do
          result = service.get_follow_up_content
          expect(result[:message]).to eq('Follow up message')
          expect(result[:metadata]).to eq({ 'key' => 'value' })
        end
      end

      context 'when API returns 400' do
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

        it 'notifies slack and returns nil' do
          expect(Stark::SlackMessageFormatter).to receive(:format_follow_up_error).and_return('error formatted')
          expect(service).to receive(:log_and_notify_slack).with('error formatted')

          expect(service.get_follow_up_content).to be_nil
        end
      end

      context 'when API raises an error' do
        before do
          allow(HTTParty).to receive(:post).and_raise(StandardError.new('Connection failed'))
          stub_const('Stark::FollowUpService::RETRY_DELAY', 0)
        end

        it 'retries and notifies slack' do
          expect(HTTParty).to receive(:post).twice
          expect(service).to receive(:log_and_notify_slack)

          expect(service.get_follow_up_content).to be_nil
        end
      end
    end
  end
end
